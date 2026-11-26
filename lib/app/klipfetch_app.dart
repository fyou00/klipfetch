import 'dart:async';

import 'package:flutter/material.dart';
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
    final themeMode = ref.watch(
      settingsProvider.select((s) => s.themeMode.toFlutterThemeMode()),
    );
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
      darkTheme: KlipFetchTheme.dark(),
      themeMode: themeMode,
      home: Scaffold(
        body: IndexedStack(
          index: selectedTab,
          children: [
            HomeScreen(skipClipboardCheck: widget.skipPlatformBootstrap),
            const DownloadsScreen(),
            SettingsScreen(skipVersionProbe: widget.skipPlatformBootstrap),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedTab,
          onDestinationSelected: (index) {
            ref.read(selectedTabProvider.notifier).select(index);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: activeCount > 0,
                label: Text('$activeCount'),
                child: const Icon(Icons.download_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: activeCount > 0,
                label: Text('$activeCount'),
                child: const Icon(Icons.download_rounded),
              ),
              label: 'Downloads',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
