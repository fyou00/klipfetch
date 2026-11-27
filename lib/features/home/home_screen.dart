import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../models/media_platform.dart';
import '../../models/media_probe.dart';
import '../../services/url_extractor.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/editorial_controls.dart';
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

      final items = await ref
          .read(downloadQueueProvider.notifier)
          .enqueuePlaylistSelection(
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

  Widget _buildUrlField(HomeProbeState probeState, {required bool hasError}) {
    final isUnsupported =
        probeState.inputUrl.isNotEmpty &&
        probeState.detectedPlatform == MediaPlatform.unsupported;

    return TextField(
      key: const Key('home_url_input'),
      controller: _urlController,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.search,
      style: KlipFetchTheme.monoStyle(
        size: 12.5,
        color: KlipFetchTheme.lightInk,
      ),
      onChanged: (value) {
        ref.read(homeProbeProvider.notifier).updateUrl(value);
      },
      onSubmitted: (_) {
        ref.read(homeProbeProvider.notifier).probeCurrentUrl();
      },
      decoration: InputDecoration(
        hintText: 'https://tiktok.com/… or youtu.be/…',
        prefixIcon: Icon(
          Icons.link_rounded,
          size: 18,
          color: (hasError || isUnsupported)
              ? KlipFetchTheme.lightError
              : KlipFetchTheme.lightMutedInk,
        ),
        enabledBorder: (hasError || isUnsupported)
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: KlipFetchTheme.lightError),
              )
            : null,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (probeState.inputUrl.isNotEmpty)
                IconButton(
                  key: const Key('home_clear_button'),
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _urlController.clear();
                    ref.read(homeProbeProvider.notifier).clear();
                  },
                ),
              IconButton(
                key: const Key('home_paste_button'),
                tooltip: 'Paste',
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                onPressed: _pasteFromClipboard,
              ),
            ],
          ),
        ),
      ),
    );
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
    final probe = probeState.probeResult;
    final hasError = probeState.errorMessage != null;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (probe == null) ...[
            const EditorialMasthead(title: 'KlipFetch'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: KlipFetchTheme.lightBorder),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Supported',
                    style: TextStyle(
                      fontFamily: KlipFetchTheme.bodyFontFamily,
                      fontSize: 12,
                      color: KlipFetchTheme.lightMutedInk,
                    ),
                  ),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      PlatformBadge(platform: MediaPlatform.tiktok, compact: true),
                      PlatformBadge(
                        platform: MediaPlatform.instagram,
                        compact: true,
                      ),
                      PlatformBadge(platform: MediaPlatform.youtube, compact: true),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_clipboardSuggestedUrl != null) ...[
                    EditorialWell(
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Link found in clipboard',
                                  style: theme.textTheme.labelMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _clipboardSuggestedUrl!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: KlipFetchTheme.monoStyle(size: 11.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () {
                              final candidate = _clipboardSuggestedUrl!;
                              setState(() {
                                _clipboardSuggestedUrl = null;
                              });
                              ref
                                  .read(homeProbeProvider.notifier)
                                  .probeUrl(candidate);
                            },
                            child: const Text('Fetch'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('Paste media URL', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _buildUrlField(probeState, hasError: hasError),
                  if (probeState.inputUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PlatformBadge(
                          platform: probeState.detectedPlatform,
                          compact: true,
                        ),
                        const SizedBox(width: 10),
                        if (probeState.detectedPlatform ==
                            MediaPlatform.unsupported)
                          Expanded(
                            child: Text(
                              'Only TikTok, Instagram, and YouTube are supported.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: KlipFetchTheme.lightError,
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
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: KlipFetchTheme.lightMutedInk,
                            ),
                          )
                        : const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      probeState.isProbing ? 'Fetching info…' : 'Fetch Media',
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 14),
                    _AuthOrProbeErrorWell(
                      message: probeState.errorMessage!,
                      showAuthButton: _looksLikeAuthError(
                            probeState.errorMessage!,
                          ) &&
                          probeState.detectedPlatform !=
                              MediaPlatform.unsupported,
                      platformName: probeState.detectedPlatform.displayName,
                      onSignIn: _openAuthScreen,
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    const EditorialHairline(),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: KlipFetchTheme.lightBorder),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share from other apps',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Send any TikTok, Instagram, or YouTube link straight to KlipFetch via the Android Share menu.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: KlipFetchTheme.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved downloads folder',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Downloads/KlipFetch/{TikTok,Instagram,YouTube}',
                            style: KlipFetchTheme.monoStyle(size: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Probed Spec Sheet view: compact URL strip + heavy 2px rule + flat spec sheet
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUrlField(probeState, hasError: hasError),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                              EditorialStatusTag(
                                label:
                                    'Playlist (${probe.playlistEntries.length} videos)',
                                outlined: true,
                              ),
                            if (!probe.isPlaylist && probe.isCarousel)
                              EditorialStatusTag(
                                label: probe.platform == MediaPlatform.tiktok
                                    ? 'Slideshow (${probe.photoSlideCount} photos)'
                                    : 'Carousel (${probe.photoSlideCount} items)',
                                outlined: true,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: const Key('home_fetch_button'),
                        onPressed: probeState.isProbing
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                ref
                                    .read(homeProbeProvider.notifier)
                                    .probeCurrentUrl();
                              },
                        child: Text(
                          probeState.isProbing ? 'Fetching…' : 'Fetch Media',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const EditorialHeavyRule(),
            if (hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _AuthOrProbeErrorWell(
                  message: probeState.errorMessage!,
                  showAuthButton: _looksLikeAuthError(
                        probeState.errorMessage!,
                      ) &&
                      probeState.detectedPlatform != MediaPlatform.unsupported,
                  platformName: probeState.detectedPlatform.displayName,
                  onSignIn: _openAuthScreen,
                ),
              ),
            _ProbeSpecSheet(
              probeState: probeState,
              durationText: _formatDuration(probe.durationSeconds),
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

class _AuthOrProbeErrorWell extends StatelessWidget {
  const _AuthOrProbeErrorWell({
    required this.message,
    required this.showAuthButton,
    required this.platformName,
    required this.onSignIn,
  });

  final String message;
  final bool showAuthButton;
  final String platformName;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return EditorialWell(
      fillColor: KlipFetchTheme.lightErrorFill,
      borderColor: KlipFetchTheme.lightErrorBorder,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: KlipFetchTheme.lightError,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: KlipFetchTheme.bodyFontFamily,
                    fontSize: 13,
                    color: KlipFetchTheme.lightInk,
                  ),
                ),
              ),
            ],
          ),
          if (showAuthButton) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: const Key('home_auth_error_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KlipFetchTheme.lightError,
                  side: const BorderSide(color: KlipFetchTheme.lightError),
                ),
                onPressed: onSignIn,
                icon: const Icon(Icons.vpn_key_outlined, size: 16),
                label: Text('Sign in to $platformName'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProbeSpecSheet extends StatelessWidget {
  const _ProbeSpecSheet({
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
      case 'best':
        return 'Best (${option.format})';
      default:
        return '${option.label} (${option.format})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final probe = probeState.probeResult!;
    final theme = Theme.of(context);
    final isYouTube = probe.platform == MediaPlatform.youtube;
    final isTikTok = probe.platform == MediaPlatform.tiktok;
    final selectableQualities = probe.qualities
        .where((q) => q.label != 'slideshow_audio')
        .toList(growable: false);
    final selectedPlaylistCount = probeState.selectedPlaylistIndices.length;
    final downloadDisabled = probe.isPlaylist && selectedPlaylistCount == 0;
    final hasThumbnail =
        probe.thumbnailUrl != null && probe.thumbnailUrl!.isNotEmpty;

    return Container(
      key: const Key('home_preview_card'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!probe.isPlaylist) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 168,
                decoration: BoxDecoration(
                  color: KlipFetchTheme.lightInk,
                  border: Border.all(color: KlipFetchTheme.lightControlOutline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasThumbnail)
                      Image.network(
                        probe.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const _EditorialPosterFallback(),
                      )
                    else
                      const _EditorialPosterFallback(),
                    if (durationText.isNotEmpty)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xE614110F),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            durationText,
                            style: KlipFetchTheme.monoStyle(
                              size: 11,
                              height: 1.2,
                              color: KlipFetchTheme.lightOnPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            probe.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KlipFetchTheme.displayStyle(
              size: 20,
              wdth: 85,
              height: 1.15,
              letterSpacing: -0.2,
            ),
          ),
          if (probe.author.isNotEmpty ||
              (probe.isPlaylist && durationText.isNotEmpty)) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (probe.author.isNotEmpty)
                  Expanded(
                    child: Text(
                      probe.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (probe.isPlaylist && durationText.isNotEmpty)
                  Text(
                    durationText,
                    style: KlipFetchTheme.monoStyle(
                      size: 11.5,
                      color: KlipFetchTheme.lightMutedInk,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          EditorialSegmentedControl<bool>(
            options: const [
              EditorialSegmentOption(value: false, label: 'Video'),
              EditorialSegmentOption(value: true, label: 'Audio Only'),
            ],
            selected: probeState.audioOnly,
            onSelected: onAudioOnlyChanged,
          ),
          const SizedBox(height: 14),
          if (!probeState.audioOnly) ...[
            if (probe.isCarousel)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  isTikTok
                      ? 'TikTok slideshow (${probe.photoSlideCount} slides)'
                      : 'Instagram carousel (${probe.photoSlideCount} items)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: KlipFetchTheme.inkSecondary,
                  ),
                ),
              )
            else if (selectableQualities.isNotEmpty) ...[
              Text('Quality', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectableQualities.map((option) {
                  final selected =
                      probeState.selectedFormat?.formatId == option.formatId &&
                      probeState.selectedFormat?.label == option.label;
                  return EditorialSpecChip(
                    label: _formatQualityChipLabel(option),
                    selected: selected,
                    onTap: () => onFormatSelected(option),
                  );
                }).toList(),
              ),
            ],
          ] else ...[
            Text('Audio Format', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AppSettings.supportedAudioFormats.map((fmt) {
                return EditorialSpecChip(
                  label: fmt.toUpperCase(),
                  selected: probeState.selectedAudioFormat == fmt,
                  onTap: () => onAudioFormatSelected(fmt),
                );
              }).toList(),
            ),
          ],
          if (isTikTok &&
              probe.hasSlideshowAudio &&
              !probeState.audioOnly) ...[
            const SizedBox(height: 12),
            const EditorialHairline(),
            EditorialSwitchRow(
              key: const Key('home_tiktok_slideshow_audio_switch'),
              title: 'Include slideshow background audio',
              value: probeState.tiktokSlideshowIncludeAudio,
              onChanged: onTiktokSlideshowIncludeAudioChanged,
              showBottomHairline: false,
            ),
          ],
          if (isYouTube && !probeState.audioOnly) ...[
            const SizedBox(height: 12),
            Container(
              height: 46,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: KlipFetchTheme.lightBorder),
                  bottom: BorderSide(color: KlipFetchTheme.lightBorder),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Video Container', style: theme.textTheme.labelLarge),
                  EditorialSegmentedControl<String>(
                    compact: true,
                    options: AppSettings.supportedVideoContainers
                        .map(
                          (c) => EditorialSegmentOption(
                            value: c,
                            label: c.toUpperCase(),
                          ),
                        )
                        .toList(),
                    selected: probeState.videoContainer,
                    onSelected: onVideoContainerChanged,
                  ),
                ],
              ),
            ),
            EditorialSwitchRow(
              key: const Key('home_subtitles_switch'),
              title: 'Download subtitles (SRT/VTT)',
              subtitle: probe.availableSubtitles.isNotEmpty
                  ? 'Available: ${probe.availableSubtitles.take(5).join(", ")}'
                  : null,
              value: probeState.downloadSubtitles,
              onChanged: onDownloadSubtitlesChanged,
            ),
            if (probeState.downloadSubtitles)
              EditorialSwitchRow(
                key: const Key('home_embed_subtitles_switch'),
                title: 'Embed subtitles into video',
                value: probeState.embedSubtitles,
                onChanged: onEmbedSubtitlesChanged,
              ),
          ],
          if (isYouTube)
            EditorialSwitchRow(
              key: const Key('home_sponsorblock_switch'),
              title: 'Remove SponsorBlock segments',
              value: probeState.sponsorBlockEnabled,
              onChanged: onSponsorBlockChanged,
              showBottomHairline: probe.isPlaylist,
            ),
          if (probe.isPlaylist) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Playlist Videos ($selectedPlaylistCount/${probe.playlistEntries.length})',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('home_playlist_select_all'),
                  onPressed: onSelectAllPlaylist,
                  child: const Text('All'),
                ),
                TextButton(
                  key: const Key('home_playlist_clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: KlipFetchTheme.inkSecondary,
                  ),
                  onPressed: onClearPlaylist,
                  child: const Text('None'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Material(
              color: KlipFetchTheme.lightSurfaceSubtle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: KlipFetchTheme.lightBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: probe.playlistEntries.length,
                  separatorBuilder: (context, index) =>
                      const EditorialHairline(),
                  itemBuilder: (context, idx) {
                    final entry = probe.playlistEntries[idx];
                    final checked = probeState.selectedPlaylistIndices
                        .contains(entry.index);
                    return CheckboxListTile(
                      key: Key('playlist_entry_${entry.index}'),
                      dense: true,
                      activeColor: KlipFetchTheme.brandAccent,
                      checkColor: KlipFetchTheme.lightOnPrimary,
                      side: const BorderSide(
                        color: KlipFetchTheme.lightControlOutline,
                        width: 1.5,
                      ),
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      value: checked,
                      title: Text(
                        '${entry.index}. ${entry.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: KlipFetchTheme.bodyFontFamily,
                          fontSize: 13,
                          fontWeight:
                              checked ? FontWeight.w600 : FontWeight.w400,
                          color: KlipFetchTheme.lightInk,
                        ),
                      ),
                      onChanged: (_) => onTogglePlaylistEntry(entry.index),
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('home_download_button'),
            onPressed: downloadDisabled ? null : onDownload,
            icon: const Icon(Icons.download_rounded, size: 18),
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
    );
  }
}

class _EditorialPosterFallback extends StatelessWidget {
  const _EditorialPosterFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF231E1B),
      ),
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          size: 36,
          color: KlipFetchTheme.lightOnPrimary.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}
