import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/downloads/downloads_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

class KlipFetchApp extends ConsumerStatefulWidget {
  const KlipFetchApp({super.key, this.skipPlatformBootstrap = false});

  final bool skipPlatformBootstrap;

  @override
  ConsumerState<KlipFetchApp> createState() => _KlipFetchAppState();
}

class _KlipFetchAppState extends ConsumerState<KlipFetchApp> {
  StreamSubscription<String>? _sharedSub;
  StreamSubscription<String>? _cancelSub;

  @override
  void initState() {
    super.initState();
    if (!widget.skipPlatformBootstrap) {
      unawaited(_bootstrap());
    }
  }

  Future<void> _bootstrap() async {
    await ref.read(settingsProvider.notifier).load();

    try {
      await ref.read(rustCoreServiceProvider).init();
    } catch (_) {
      // Allow UI startup even if FFI dynamic library is unavailable in tests.
    }

    try {
      await ref.read(ytDlpServiceProvider).init();
    } catch (_) {
      // Non-Android / test environments safely defer yt-dlp initialization.
    }

    try {
      await ref.read(downloadQueueProvider.notifier).loadPersistedQueue();
    } catch (_) {
      // Queue storage unavailable before initCore succeeds.
    }

    try {
      await ref.read(cookieStatusesProvider.notifier).refresh();
    } catch (_) {
      // Cookie store unavailable before initCore succeeds.
    }

    final platformClient = ref.read(androidPlatformProvider);
    _sharedSub = platformClient.sharedTextStream.listen((text) {
      unawaited(_handleSharedText(text));
    });
    _cancelSub = platformClient.notificationCancelStream.listen((taskId) {
      unawaited(ref.read(downloadQueueProvider.notifier).cancelTask(taskId));
    });

    final initialShared = await platformClient.getInitialSharedText();
    if (initialShared != null && initialShared.trim().isNotEmpty) {
      await _handleSharedText(initialShared);
    }
  }

  Future<void> _handleSharedText(String sharedText) async {
    ref.read(selectedTabProvider.notifier).select(0);
    await ref.read(homeProbeProvider.notifier).applySharedText(sharedText);
  }

  @override
  void dispose() {
    _sharedSub?.cancel();
    _cancelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(selectedTabProvider);
    final activeCount = ref.watch(
      downloadQueueProvider.select(
        (items) => items.where((item) => item.isActive).length,
      ),
    );

    return MaterialApp(
      title: 'KlipFetch',
      debugShowCheckedModeBanner: false,
      theme: KlipFetchTheme.light(),
      themeMode: ThemeMode.light,
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: KlipFetchTheme.lightBackground,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: KlipFetchTheme.lightSurface,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          body: IndexedStack(
            index: selectedTab,
            children: [
              HomeScreen(skipClipboardCheck: widget.skipPlatformBootstrap),
              const DownloadsScreen(),
              SettingsScreen(skipVersionProbe: widget.skipPlatformBootstrap),
            ],
          ),
          bottomNavigationBar: _EditorialBottomNavBar(
            selectedIndex: selectedTab,
            activeCount: activeCount,
            onSelect: (index) {
              ref.read(selectedTabProvider.notifier).select(index);
            },
          ),
        ),
      ),
    );
  }
}

class _EditorialBottomNavBar extends StatelessWidget {
  const _EditorialBottomNavBar({
    required this.selectedIndex,
    required this.activeCount,
    required this.onSelect,
  });

  final int selectedIndex;
  final int activeCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KlipFetchTheme.lightSurface,
        border: Border(
          top: BorderSide(color: KlipFetchTheme.lightBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _EditorialNavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
              ),
              _EditorialNavItem(
                label: 'Downloads',
                icon: Icons.download_outlined,
                selectedIcon: Icons.download_rounded,
                selected: selectedIndex == 1,
                badgeCount: activeCount,
                onTap: () => onSelect(1),
              ),
              _EditorialNavItem(
                label: 'Settings',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                selected: selectedIndex == 2,
                onTap: () => onSelect(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorialNavItem extends StatelessWidget {
  const _EditorialNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        selected ? KlipFetchTheme.brandAccent : KlipFetchTheme.lightMutedInk;
    final labelColor =
        selected ? KlipFetchTheme.lightInk : KlipFetchTheme.lightMutedInk;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 56,
                height: 2,
                child: ColoredBox(
                  color: selected
                      ? KlipFetchTheme.brandAccent
                      : Colors.transparent,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? selectedIcon : icon,
                    size: 20,
                    color: iconColor,
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: KlipFetchTheme.brandAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: KlipFetchTheme.monoStyle(
                          size: 10,
                          height: 1.2,
                          color: KlipFetchTheme.lightOnPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: KlipFetchTheme.bodyFontFamily,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
