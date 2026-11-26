import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../models/media_platform.dart';
import '../../models/media_probe.dart';
import '../../services/url_extractor.dart';
import '../../state/providers.dart';
import '../../widgets/platform_badge.dart';
import '../auth/auth_browser_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.skipClipboardCheck = false});

  final bool skipClipboardCheck;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _urlController;
  String? _clipboardSuggestedUrl;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: ref.read(homeProbeProvider).inputUrl,
    );
    WidgetsBinding.instance.addObserver(this);
    if (!widget.skipClipboardCheck) {
      unawaited(_checkClipboard());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !widget.skipClipboardCheck) {
      unawaited(_checkClipboard());
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (!mounted || text == null || text.trim().isEmpty) return;
      final candidate = extractSupportedUrlFromText(text);
      if (candidate == null) return;
      final current = ref.read(homeProbeProvider).inputUrl.trim();
      if (candidate != current) {
        setState(() {
          _clipboardSuggestedUrl = candidate;
        });
      }
    } catch (_) {
      // Clipboard may be restricted by Android privacy prompts; ignore quietly.
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (!mounted || raw.isEmpty) return;

    final extracted = extractSupportedUrlFromText(raw) ?? raw;
    _urlController.text = extracted;
    _urlController.selection = TextSelection.collapsed(
      offset: extracted.length,
    );
    setState(() {
      _clipboardSuggestedUrl = null;
    });
    ref.read(homeProbeProvider.notifier).updateUrl(extracted);
  }

  bool _looksLikeAuthError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('login') ||
        lower.contains('cookie') ||
        lower.contains('private') ||
        lower.contains('story') ||
        lower.contains('stories') ||
        lower.contains('sign in') ||
        lower.contains('401') ||
        lower.contains('403');
  }

  void _openAuthScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AuthBrowserScreen(),
      ),
    );
  }

  Future<void> _startDownload(HomeProbeState probeState) async {
    final probe = probeState.probeResult;
    if (probe == null) return;

    final settings = ref.read(settingsProvider);
    final selected = probeState.selectedFormat;
    final isYouTube = probe.platform == MediaPlatform.youtube;
    final enableSubs =
        isYouTube && !probeState.audioOnly && probeState.downloadSubtitles;
    final sponsorCategories = (isYouTube && probeState.sponsorBlockEnabled)
        ? settings.sponsorBlockCategories
        : const <String>[];
    final mergeContainer =
        (isYouTube && !probeState.audioOnly) ? probeState.videoContainer : null;

    if (probe.isPlaylist) {
      final selectedEntries = probe.playlistEntries
          .where((e) => probeState.selectedPlaylistIndices.contains(e.index))
          .toList(growable: false);
      if (selectedEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one playlist item.')),
        );
        return;
      }

      final items =
          await ref.read(downloadQueueProvider.notifier).enqueuePlaylistSelection(
                entries: selectedEntries,
                preferredEngine: probe.engine,
                formatSelector: selected?.formatId,
                qualityLabel: probeState.audioOnly
                    ? probeState.selectedAudioFormat.toUpperCase()
                    : selected?.label,
                audioOnly: probeState.audioOnly,
                audioFormat: probeState.selectedAudioFormat,
                mergeOutputFormat: mergeContainer,
                downloadSubtitles: enableSubs,
                embedSubtitles: probeState.embedSubtitles,
                subtitleLangs: enableSubs ? settings.subtitleLanguages : null,
                sponsorBlockCategories: sponsorCategories,
              );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Queued ${items.length} playlist items'),
          action: SnackBarAction(
            label: 'View Queue',
            onPressed: () {
              ref.read(selectedTabProvider.notifier).select(1);
            },
          ),
        ),
      );
      return;
    }

    final qualityLabel = probeState.audioOnly
        ? probeState.selectedAudioFormat.toUpperCase()
        : (probe.platform == MediaPlatform.tiktok &&
                probe.hasSlideshowAudio &&
                probeState.tiktokSlideshowIncludeAudio
            ? 'photos_with_audio'
            : selected?.label);

    final item = await ref.read(downloadQueueProvider.notifier).enqueueDownload(
          url: probeState.inputUrl,
          platform: probe.platform,
          title: probe.title,
          preferredEngine: probe.engine,
          formatSelector: selected?.formatId,
          qualityLabel: qualityLabel,
          audioOnly: probeState.audioOnly,
          audioFormat: probeState.selectedAudioFormat,
          mergeOutputFormat: mergeContainer,
          downloadSubtitles: enableSubs,
          embedSubtitles: probeState.embedSubtitles,
          subtitleLangs: enableSubs ? settings.subtitleLanguages : null,
          sponsorBlockCategories: sponsorCategories,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queued "${item.title}"'),
        action: SnackBarAction(
          label: 'View Queue',
          onPressed: () {
            ref.read(selectedTabProvider.notifier).select(1);
          },
        ),
      ),
    );
  }

  String _formatDuration(double? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final total = seconds.round();
    final hours = total ~/ 3600;
    final mins = (total % 3600) ~/ 60;
    final secs = total % 60;
    if (hours > 0) {
      return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<HomeProbeState>(homeProbeProvider, (previous, next) {
      if (next.inputUrl != _urlController.text) {
        _urlController.text = next.inputUrl;
        _urlController.selection = TextSelection.collapsed(
          offset: next.inputUrl.length,
        );
      }
    });

    final probeState = ref.watch(homeProbeProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  Icons.download_for_offline_rounded,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KlipFetch',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'TikTok · Instagram · YouTube',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PlatformBadge(platform: MediaPlatform.tiktok, compact: true),
              PlatformBadge(platform: MediaPlatform.instagram, compact: true),
              PlatformBadge(platform: MediaPlatform.youtube, compact: true),
            ],
          ),
          const SizedBox(height: 16),
          if (_clipboardSuggestedUrl != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.content_paste_go_rounded,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supported link in clipboard',
                            style: theme.textTheme.labelLarge,
                          ),
                          Text(
                            _clipboardSuggestedUrl!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () {
                        final candidate = _clipboardSuggestedUrl!;
                        setState(() {
                          _clipboardSuggestedUrl = null;
                        });
                        ref.read(homeProbeProvider.notifier).probeUrl(candidate);
                      },
                      child: const Text('Fetch'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('home_url_input'),
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      ref.read(homeProbeProvider.notifier).updateUrl(value);
                    },
                    onSubmitted: (_) {
                      ref.read(homeProbeProvider.notifier).probeCurrentUrl();
                    },
                    decoration: InputDecoration(
                      labelText: 'Paste media URL',
                      hintText: 'https://www.tiktok.com/... or youtu.be/...',
                      prefixIcon: const Icon(Icons.link_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (probeState.inputUrl.isNotEmpty)
                            IconButton(
                              key: const Key('home_clear_button'),
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _urlController.clear();
                                ref.read(homeProbeProvider.notifier).clear();
                              },
                            ),
                          IconButton(
                            key: const Key('home_paste_button'),
                            tooltip: 'Paste',
                            icon: const Icon(Icons.content_paste_rounded),
                            onPressed: _pasteFromClipboard,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (probeState.inputUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        PlatformBadge(platform: probeState.detectedPlatform),
                        const SizedBox(width: 8),
                        if (probeState.detectedPlatform ==
                            MediaPlatform.unsupported)
                          Expanded(
                            child: Text(
                              'Only TikTok, Instagram, and YouTube are supported.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const Key('home_fetch_button'),
                    onPressed: probeState.isProbing
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            ref
                                .read(homeProbeProvider.notifier)
                                .probeCurrentUrl();
                          },
                    icon: probeState.isProbing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                    label: Text(
                      probeState.isProbing ? 'Fetching info...' : 'Fetch Media',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (probeState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              color: scheme.errorContainer.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded, color: scheme.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            probeState.errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_looksLikeAuthError(probeState.errorMessage!) &&
                        probeState.detectedPlatform !=
                            MediaPlatform.unsupported) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          key: const Key('home_auth_error_button'),
                          onPressed: _openAuthScreen,
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: Text(
                            'Sign in to ${probeState.detectedPlatform.displayName}',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (probeState.probeResult != null) ...[
            const SizedBox(height: 16),
            _ProbePreviewCard(
              probeState: probeState,
              durationText:
                  _formatDuration(probeState.probeResult!.durationSeconds),
              onAudioOnlyChanged: (audioOnly) {
                ref.read(homeProbeProvider.notifier).setAudioOnly(audioOnly);
              },
              onFormatSelected: (option) {
                ref.read(homeProbeProvider.notifier).selectFormat(option);
              },
              onAudioFormatSelected: (fmt) {
                ref.read(homeProbeProvider.notifier).setAudioFormat(fmt);
              },
              onVideoContainerChanged: (container) {
                ref
                    .read(homeProbeProvider.notifier)
                    .setVideoContainer(container);
              },
              onDownloadSubtitlesChanged: (enabled) {
                ref
                    .read(homeProbeProvider.notifier)
                    .setDownloadSubtitles(enabled);
              },
              onEmbedSubtitlesChanged: (enabled) {
                ref
                    .read(homeProbeProvider.notifier)
                    .setEmbedSubtitles(enabled);
              },
              onSponsorBlockChanged: (enabled) {
                ref
                    .read(homeProbeProvider.notifier)
                    .setSponsorBlockEnabled(enabled);
              },
              onTiktokSlideshowIncludeAudioChanged: (enabled) {
                ref
                    .read(homeProbeProvider.notifier)
                    .setTiktokSlideshowIncludeAudio(enabled);
              },
              onTogglePlaylistEntry: (index) {
                ref
                    .read(homeProbeProvider.notifier)
                    .togglePlaylistEntry(index);
              },
              onSelectAllPlaylist: () {
                ref
                    .read(homeProbeProvider.notifier)
                    .selectAllPlaylistEntries();
              },
              onClearPlaylist: () {
                ref
                    .read(homeProbeProvider.notifier)
                    .clearPlaylistSelection();
              },
              onDownload: () => _startDownload(probeState),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProbePreviewCard extends StatelessWidget {
  const _ProbePreviewCard({
    required this.probeState,
    required this.durationText,
    required this.onAudioOnlyChanged,
    required this.onFormatSelected,
    required this.onAudioFormatSelected,
    required this.onVideoContainerChanged,
    required this.onDownloadSubtitlesChanged,
    required this.onEmbedSubtitlesChanged,
    required this.onSponsorBlockChanged,
    required this.onTiktokSlideshowIncludeAudioChanged,
    required this.onTogglePlaylistEntry,
    required this.onSelectAllPlaylist,
    required this.onClearPlaylist,
    required this.onDownload,
  });

  final HomeProbeState probeState;
  final String durationText;
  final ValueChanged<bool> onAudioOnlyChanged;
  final ValueChanged<MediaFormatOption> onFormatSelected;
  final ValueChanged<String> onAudioFormatSelected;
  final ValueChanged<String> onVideoContainerChanged;
  final ValueChanged<bool> onDownloadSubtitlesChanged;
  final ValueChanged<bool> onEmbedSubtitlesChanged;
  final ValueChanged<bool> onSponsorBlockChanged;
  final ValueChanged<bool> onTiktokSlideshowIncludeAudioChanged;
  final ValueChanged<int> onTogglePlaylistEntry;
  final VoidCallback onSelectAllPlaylist;
  final VoidCallback onClearPlaylist;
  final VoidCallback onDownload;

  String _formatQualityChipLabel(MediaFormatOption option) {
    switch (option.label) {
      case '2160p':
        return '2160p (4K) (${option.format})';
      case '1440p':
        return '1440p (2K) (${option.format})';
      default:
        return '${option.label} (${option.format})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final probe = probeState.probeResult!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isYouTube = probe.platform == MediaPlatform.youtube;
    final isTikTok = probe.platform == MediaPlatform.tiktok;
    final selectableQualities = probe.qualities
        .where((q) => q.label != 'slideshow_audio')
        .toList(growable: false);
    final selectedPlaylistCount = probeState.selectedPlaylistIndices.length;
    final downloadDisabled = probe.isPlaylist && selectedPlaylistCount == 0;

    return Card(
      key: const Key('home_preview_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 96,
                    height: 72,
                    child: probe.thumbnailUrl != null &&
                            probe.thumbnailUrl!.isNotEmpty
                        ? Image.network(
                            probe.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _ThumbnailFallback(scheme: scheme),
                          )
                        : _ThumbnailFallback(scheme: scheme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PlatformBadge(
                            platform: probe.platform,
                            compact: true,
                          ),
                          EngineBadge(
                            engine: probe.engine,
                            usedFallback: probe.usedFallback,
                          ),
                          if (probe.isPlaylist)
                            _InfoPill(
                              label:
                                  'Playlist · ${probe.playlistEntries.length} videos',
                            ),
                          if (!probe.isPlaylist && probe.isCarousel)
                            _InfoPill(
                              label: isTikTok
                                  ? 'Slideshow · ${probe.photoSlideCount} photos'
                                  : 'Carousel · ${probe.photoSlideCount} items',
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        probe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (probe.author.isNotEmpty || durationText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [
                              if (probe.author.isNotEmpty) probe.author,
                              if (durationText.isNotEmpty) durationText,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Video'),
                  icon: Icon(Icons.videocam_outlined),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Audio Only'),
                  icon: Icon(Icons.audiotrack_outlined),
                ),
              ],
              selected: {probeState.audioOnly},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  onAudioOnlyChanged(selection.first);
                }
              },
            ),
            const SizedBox(height: 14),
            if (!probeState.audioOnly) ...[
              if (probe.isCarousel)
                Text(
                  isTikTok
                      ? 'TikTok slideshow (${probe.photoSlideCount} slides)'
                      : 'Instagram carousel (${probe.photoSlideCount} items)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else if (selectableQualities.isNotEmpty) ...[
                Text('Quality', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectableQualities.map((option) {
                    final selected = probeState.selectedFormat?.formatId ==
                            option.formatId &&
                        probeState.selectedFormat?.label == option.label;
                    return ChoiceChip(
                      label: Text(_formatQualityChipLabel(option)),
                      selected: selected,
                      onSelected: (_) => onFormatSelected(option),
                    );
                  }).toList(),
                ),
              ],
            ] else ...[
              Text('Audio Format', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppSettings.supportedAudioFormats.map((fmt) {
                  return ChoiceChip(
                    label: Text(fmt.toUpperCase()),
                    selected: probeState.selectedAudioFormat == fmt,
                    onSelected: (_) => onAudioFormatSelected(fmt),
                  );
                }).toList(),
              ),
            ],
            if (isTikTok &&
                probe.hasSlideshowAudio &&
                !probeState.audioOnly) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                key: const Key('home_tiktok_slideshow_audio_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Include slideshow background audio'),
                value: probeState.tiktokSlideshowIncludeAudio,
                onChanged: onTiktokSlideshowIncludeAudioChanged,
              ),
            ],
            if (isYouTube && !probeState.audioOnly) ...[
              const SizedBox(height: 14),
              Text('Video Container', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: AppSettings.supportedVideoContainers
                    .map(
                      (container) => ButtonSegment<String>(
                        value: container,
                        label: Text(container.toUpperCase()),
                      ),
                    )
                    .toList(),
                selected: {probeState.videoContainer},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    onVideoContainerChanged(selection.first);
                  }
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('home_subtitles_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Download subtitles (SRT/VTT)'),
                subtitle: probe.availableSubtitles.isNotEmpty
                    ? Text(
                        'Available: ${probe.availableSubtitles.take(5).join(", ")}',
                      )
                    : null,
                value: probeState.downloadSubtitles,
                onChanged: onDownloadSubtitlesChanged,
              ),
              if (probeState.downloadSubtitles)
                SwitchListTile(
                  key: const Key('home_embed_subtitles_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Embed subtitles into video'),
                  value: probeState.embedSubtitles,
                  onChanged: onEmbedSubtitlesChanged,
                ),
            ],
            if (isYouTube) ...[
              SwitchListTile(
                key: const Key('home_sponsorblock_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Remove SponsorBlock segments'),
                value: probeState.sponsorBlockEnabled,
                onChanged: onSponsorBlockChanged,
              ),
            ],
            if (probe.isPlaylist) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Playlist Videos ($selectedPlaylistCount/${probe.playlistEntries.length})',
                    style: theme.textTheme.labelLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('home_playlist_select_all'),
                    onPressed: onSelectAllPlaylist,
                    child: const Text('All'),
                  ),
                  TextButton(
                    key: const Key('home_playlist_clear'),
                    onPressed: onClearPlaylist,
                    child: const Text('None'),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: probe.playlistEntries.length,
                  itemBuilder: (context, idx) {
                    final entry = probe.playlistEntries[idx];
                    final checked =
                        probeState.selectedPlaylistIndices.contains(entry.index);
                    return CheckboxListTile(
                      key: Key('playlist_entry_${entry.index}'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: checked,
                      title: Text(
                        '${entry.index}. ${entry.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (_) => onTogglePlaylistEntry(entry.index),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('home_download_button'),
              onPressed: downloadDisabled ? null : onDownload,
              icon: const Icon(Icons.download_rounded),
              label: Text(
                probe.isPlaylist
                    ? 'Download $selectedPlaylistCount Selected'
                    : (probeState.audioOnly
                        ? 'Download ${probeState.selectedAudioFormat.toUpperCase()}'
                        : 'Download ${probeState.selectedFormat?.label ?? "Best"}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
      ),
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
