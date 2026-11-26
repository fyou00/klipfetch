import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../state/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.skipVersionProbe = false});

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
      unawaited(_loadYtDlpVersion());
    }
  }

  Future<void> _loadYtDlpVersion() async {
    try {
      final version = await ref.read(ytDlpServiceProvider).getVersion();
      if (!mounted) return;
      setState(() {
        _ytDlpVersion = version;
      });
    } catch (_) {
      // Non-Android / uninitialized engine is safe to ignore here.
    }
  }

  Future<void> _updateYtDlp(String channel) async {
    setState(() {
      _updatingYtDlp = true;
    });
    try {
      final status = await ref
          .read(ytDlpServiceProvider)
          .updateYtDlp(channel: channel);
      final newVersion = await ref.read(ytDlpServiceProvider).getVersion();
      if (!mounted) return;
      setState(() {
        _ytDlpVersion = newVersion;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('yt-dlp update status: ${status ?? "DONE"}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('yt-dlp update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingYtDlp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            'Settings',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Appearance', theme: theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SegmentedButton<AppThemeMode>(
                segments: AppThemeMode.values
                    .map(
                      (mode) => ButtonSegment<AppThemeMode>(
                        value: mode,
                        label: Text(mode.label),
                      ),
                    )
                    .toList(),
                selected: {settings.themeMode},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    ref
                        .read(settingsProvider.notifier)
                        .setThemeMode(selection.first);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Downloads', theme: theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Default Video Quality', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppSettings.supportedQualities.map((quality) {
                      return ChoiceChip(
                        label: Text(quality),
                        selected: settings.defaultQuality == quality,
                        onSelected: (_) {
                          ref
                              .read(settingsProvider.notifier)
                              .setDefaultQuality(quality);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Default Audio Format', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: AppSettings.supportedAudioFormats
                        .map(
                          (fmt) => ButtonSegment<String>(
                            value: fmt,
                            label: Text(fmt.toUpperCase()),
                          ),
                        )
                        .toList(),
                    selected: {settings.defaultAudioFormat},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        ref
                            .read(settingsProvider.notifier)
                            .setDefaultAudioFormat(selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Concurrent Downloads', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(value: 1, label: Text('1')),
                      ButtonSegment<int>(value: 2, label: Text('2')),
                      ButtonSegment<int>(value: 3, label: Text('3')),
                    ],
                    selected: {settings.maxConcurrentDownloads},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        ref
                            .read(settingsProvider.notifier)
                            .setMaxConcurrentDownloads(selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-retry failed downloads'),
                    subtitle: const Text(
                      'Retries transient failures with exponential backoff',
                    ),
                    value: settings.autoRetry,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setAutoRetry(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'yt-dlp Engine', theme: theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Installed version: ${_ytDlpVersion ?? "Not initialized"}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'stable',
                        label: Text('Stable'),
                      ),
                      ButtonSegment<String>(
                        value: 'nightly',
                        label: Text('Nightly'),
                      ),
                    ],
                    selected: {settings.updateChannel},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        ref
                            .read(settingsProvider.notifier)
                            .setUpdateChannel(selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _updatingYtDlp
                        ? null
                        : () => _updateYtDlp(settings.updateChannel),
                    icon: _updatingYtDlp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt_rounded),
                    label: Text(
                      _updatingYtDlp ? 'Updating yt-dlp...' : 'Update yt-dlp',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Android & Storage', theme: theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notification Permission'),
                  subtitle: const Text(
                    'Required on Android 13+ for foreground download progress',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final granted = await ref
                          .read(androidPlatformProvider)
                          .requestNotificationPermission();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            granted
                                ? 'Notification permission granted'
                                : 'Notification permission denied',
                          ),
                        ),
                      );
                    },
                    child: const Text('Grant'),
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                const ListTile(
                  leading: Icon(Icons.folder_outlined),
                  title: Text('Saved Downloads Location'),
                  subtitle: Text(
                    'Downloads/KlipFetch/{TikTok,Instagram,YouTube}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'About & License', theme: theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KlipFetch v1.0.0',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Licensed under GNU General Public License v3.0 (GPL-3.0).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Powered by libreget-core (OpenSelena/libreget), yt-dlp, youtubedl-android, FFmpeg, and Flutter Rust Bridge.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
