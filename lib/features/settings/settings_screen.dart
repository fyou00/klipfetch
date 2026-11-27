import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/editorial_controls.dart';
import '../auth/auth_browser_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.skipVersionProbe = false,
  });

  final bool skipVersionProbe;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _ytDlpVersion;
  bool _updatingYtDlp = false;

  @override
  void initState() {
    super.initState();
    if (!widget.skipVersionProbe) {
      Future<void>.microtask(_loadYtDlpVersion);
    }
  }

  Future<void> _loadYtDlpVersion() async {
    try {
      final version = await ref.read(ytDlpServiceProvider).getVersion();
      if (!mounted) return;
      setState(() {
        final trimmed = version?.trim();
        _ytDlpVersion =
            (trimmed == null || trimmed.isEmpty) ? null : trimmed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ytDlpVersion = null);
    }
  }

  Future<void> _updateYtDlp(String channel) async {
    if (_updatingYtDlp) return;
    setState(() => _updatingYtDlp = true);
    try {
      final updatedVersion = await ref
          .read(ytDlpServiceProvider)
          .updateYtDlp(channel: channel);
      if (!mounted) return;
      final cleaned = updatedVersion?.trim();
      if (cleaned != null && cleaned.isNotEmpty) {
        setState(() => _ytDlpVersion = cleaned);
      } else {
        await _loadYtDlpVersion();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cleaned != null && cleaned.isNotEmpty
                ? 'yt-dlp updated ($channel): $cleaned'
                : 'yt-dlp is up to date ($channel).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('yt-dlp update failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingYtDlp = false);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    final granted =
        await ref.read(androidPlatformProvider).requestNotificationPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Notification permission granted.'
              : 'Notification permission was not granted.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final cookieStatuses = ref.watch(cookieStatusesProvider);
    final connectedCount =
        cookieStatuses.values.where((status) => status.isConnected).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
          children: [
            EditorialMasthead(
              title: 'Settings',
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
              trailing: Text(
                'v0.1.1',
                style: KlipFetchTheme.monoStyle(
                  size: 12,
                  color: KlipFetchTheme.lightMutedInk,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Appearance ───────────────────────────────────────────────
            const _SectionHeading(
              kicker: 'DISPLAY',
              title: 'Appearance',
            ),
            const SizedBox(height: 10),
            EditorialSegmentedControl<AppThemeMode>(
              locked: true,
              selected: AppThemeMode.light,
              onSelected: (_) {},
              options: AppThemeMode.values
                  .map(
                    (mode) => EditorialSegmentOption<AppThemeMode>(
                      value: mode,
                      label: mode.label,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Light Mode is locked. Theme switching is currently disabled.',
              key: const Key('settings_theme_locked_caption'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: KlipFetchTheme.lightMutedInk,
              ),
            ),
            const SizedBox(height: 14),

            // ── Accounts & Cookies entry ─────────────────────────────────
            Material(
              color: KlipFetchTheme.lightSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: KlipFetchTheme.lightBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('settings_accounts_tile'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AuthBrowserScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: KlipFetchTheme.lightSurfaceSubtle,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: KlipFetchTheme.lightBorder,
                          ),
                        ),
                        child: const Icon(
                          Icons.key_rounded,
                          size: 18,
                          color: KlipFetchTheme.lightInk,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accounts & Cookies',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$connectedCount of 3 platforms connected',
                              style: KlipFetchTheme.monoStyle(
                                size: 12,
                                color: connectedCount > 0
                                    ? const Color(0xFF166835)
                                    : KlipFetchTheme.lightMutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: KlipFetchTheme.lightMutedInk,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const EditorialHeavyRule(),
            const SizedBox(height: 18),

            // ── Downloads Defaults ───────────────────────────────────────
            const _SectionHeading(
              kicker: 'DEFAULTS',
              title: 'Downloads',
            ),
            const SizedBox(height: 12),
            Text(
              'Default Video Quality',
              style: theme.textTheme.labelMedium?.copyWith(
                color: KlipFetchTheme.inkSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _QualitySelectorRow(
              selectedQuality: settings.defaultQuality,
              onSelect: notifier.setDefaultQuality,
            ),
            const SizedBox(height: 14),
            const EditorialHairline(),
            _InlineSegmentedSettingRow<String>(
              label: 'Default Video Container',
              selected: settings.defaultVideoContainer,
              onSelected: notifier.setDefaultVideoContainer,
              options: AppSettings.supportedVideoContainers
                  .map(
                    (c) => EditorialSegmentOption<String>(
                      value: c,
                      label: c.toUpperCase(),
                    ),
                  )
                  .toList(),
            ),
            const EditorialHairline(),
            _InlineSegmentedSettingRow<String>(
              label: 'Default Audio Format',
              selected: settings.defaultAudioFormat,
              onSelected: notifier.setDefaultAudioFormat,
              options: AppSettings.supportedAudioFormats
                  .map(
                    (fmt) => EditorialSegmentOption<String>(
                      value: fmt,
                      label: fmt.toUpperCase(),
                    ),
                  )
                  .toList(),
            ),
            const EditorialHairline(),
            _InlineSegmentedSettingRow<int>(
              label: 'Concurrent Downloads',
              selected: settings.maxConcurrentDownloads,
              tabular: true,
              onSelected: notifier.setMaxConcurrentDownloads,
              options: const [1, 2, 3]
                  .map(
                    (count) => EditorialSegmentOption<int>(
                      value: count,
                      label: '$count',
                    ),
                  )
                  .toList(),
            ),
            const EditorialHairline(),
            EditorialSwitchRow(
              title: 'Auto-retry failed downloads',
              subtitle: 'Retry transient network interruptions automatically',
              value: settings.autoRetry,
              onChanged: notifier.setAutoRetry,
            ),
            EditorialSwitchRow(
              key: const Key('settings_subtitles_switch'),
              title: 'Download subtitles',
              subtitle: 'Fetch Indonesian and English subtitle tracks',
              value: settings.downloadSubtitles,
              onChanged: notifier.setDownloadSubtitles,
              showBottomHairline: true,
            ),
            if (settings.downloadSubtitles)
              EditorialSwitchRow(
                title: 'Embed subtitles in video',
                subtitle: 'Mux subtitle tracks directly into MP4/MKV output',
                value: settings.embedSubtitles,
                onChanged: notifier.setEmbedSubtitles,
              ),
            EditorialSwitchRow(
              key: const Key('settings_sponsorblock_switch'),
              title: 'SponsorBlock skip',
              subtitle: 'Skip sponsored segments on YouTube downloads',
              value: settings.sponsorBlockEnabled,
              onChanged: notifier.setSponsorBlockEnabled,
            ),
            EditorialSwitchRow(
              title: 'TikTok slideshow audio',
              subtitle: 'Include background music when fetching photo carousels',
              value: settings.tiktokSlideshowIncludeAudio,
              onChanged: notifier.setTiktokSlideshowIncludeAudio,
              showBottomHairline: false,
            ),

            const SizedBox(height: 16),
            const EditorialHeavyRule(),
            const SizedBox(height: 18),

            // ── yt-dlp Engine ────────────────────────────────────────────
            const _SectionHeading(
              kicker: 'ENGINE',
              title: 'yt-dlp Engine',
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _loadYtDlpVersion,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Engine version',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Installed ${_ytDlpVersion ?? "Not initialized"}',
                            style: KlipFetchTheme.monoStyle(
                              size: 12,
                              color: KlipFetchTheme.lightMutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: KlipFetchTheme.lightMutedInk,
                    ),
                  ],
                ),
              ),
            ),
            const EditorialHairline(),
            _InlineSegmentedSettingRow<String>(
              label: 'Update channel',
              selected: settings.updateChannel,
              onSelected: notifier.setUpdateChannel,
              options: const [
                EditorialSegmentOption<String>(
                  value: 'stable',
                  label: 'Stable',
                ),
                EditorialSegmentOption<String>(
                  value: 'nightly',
                  label: 'Nightly',
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _updatingYtDlp
                    ? null
                    : () => _updateYtDlp(settings.updateChannel),
                icon: _updatingYtDlp
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: KlipFetchTheme.lightInk,
                        ),
                      )
                    : const Icon(Icons.system_update_alt_rounded, size: 17),
                label: Text(
                  _updatingYtDlp ? 'Updating yt-dlp...' : 'Update yt-dlp',
                ),
              ),
            ),

            const SizedBox(height: 20),
            const EditorialHeavyRule(),
            const SizedBox(height: 18),

            // ── Android & Storage ────────────────────────────────────────
            const _SectionHeading(
              kicker: 'SYSTEM',
              title: 'Android & Storage',
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification Permission',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Required for active foreground transfer alerts',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KlipFetchTheme.lightMutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                    ),
                    onPressed: _requestNotificationPermission,
                    child: const Text('Grant'),
                  ),
                ],
              ),
            ),
            const EditorialHairline(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved Downloads Location',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Downloads/KlipFetch/{TikTok,Instagram,YouTube}',
                          style: KlipFetchTheme.monoStyle(
                            size: 12,
                            color: KlipFetchTheme.lightMutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.folder_open_rounded,
                    size: 18,
                    color: KlipFetchTheme.lightMutedInk,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const EditorialHeavyRule(),
            const SizedBox(height: 18),

            // ── Colophon & License ───────────────────────────────────────
            EditorialWell(
              fillColor: KlipFetchTheme.lightSurfaceSubtle,
              borderColor: KlipFetchTheme.lightBorder,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'KlipFetch',
                        style: KlipFetchTheme.displayStyle(
                          size: 18,
                          wdth: 85,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'v0.1.1',
                        style: KlipFetchTheme.monoStyle(
                          size: 11.5,
                          color: KlipFetchTheme.lightMutedInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Licensed under GNU General Public License v3.0 (GPL-3.0). Powered by libreget-core (OpenSelena/libreget), yt-dlp, youtubedl-android, FFmpeg, and Flutter Rust Bridge.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: KlipFetchTheme.inkSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.kicker,
    required this.title,
  });

  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style: KlipFetchTheme.monoStyle(
            size: 10.5,
            color: KlipFetchTheme.lightMutedInk,
          ).copyWith(letterSpacing: 1.1),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
      ],
    );
  }
}

class _QualitySelectorRow extends StatelessWidget {
  const _QualitySelectorRow({
    required this.selectedQuality,
    required this.onSelect,
  });

  final String selectedQuality;
  final ValueChanged<String> onSelect;

  static String _labelFor(String quality) {
    return quality == 'best' ? 'Best' : quality;
  }

  @override
  Widget build(BuildContext context) {
    const qualities = AppSettings.supportedQualities;
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleRow = constraints.maxWidth >= 380;
        if (singleRow) {
          return Row(
            children: [
              for (var i = 0; i < qualities.length; i++) ...[
                EditorialSpecChip(
                  expand: true,
                  label: _labelFor(qualities[i]),
                  selected: selectedQuality == qualities[i],
                  onTap: () => onSelect(qualities[i]),
                ),
                if (i < qualities.length - 1) const SizedBox(width: 4),
              ],
            ],
          );
        }

        final firstHalf = qualities.sublist(0, 3);
        final secondHalf = qualities.sublist(3);
        return Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < firstHalf.length; i++) ...[
                  EditorialSpecChip(
                    expand: true,
                    label: _labelFor(firstHalf[i]),
                    selected: selectedQuality == firstHalf[i],
                    onTap: () => onSelect(firstHalf[i]),
                  ),
                  if (i < firstHalf.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < secondHalf.length; i++) ...[
                  EditorialSpecChip(
                    expand: true,
                    label: _labelFor(secondHalf[i]),
                    selected: selectedQuality == secondHalf[i],
                    onTap: () => onSelect(secondHalf[i]),
                  ),
                  if (i < secondHalf.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _InlineSegmentedSettingRow<T> extends StatelessWidget {
  const _InlineSegmentedSettingRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.tabular = false,
  });

  final String label;
  final List<EditorialSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          EditorialSegmentedControl<T>(
            compact: true,
            tabular: tabular,
            selected: selected,
            onSelected: onSelected,
            options: options,
          ),
        ],
      ),
    );
  }
}
