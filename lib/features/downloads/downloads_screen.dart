import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/queue_item.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/platform_badge.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  bool _showHistory = false;

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    const kb = 1024.0;
    const mb = kb * 1024.0;
    const gb = mb * 1024.0;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  String _formatSpeed(double? speedBps) {
    if (speedBps == null || speedBps <= 0) return '';
    final mbps = speedBps / (1024 * 1024);
    if (mbps >= 1.0) return '${mbps.toStringAsFixed(1)} MB/s';
    return '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
  }

  String _formatEta(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    if (seconds < 60) return '${seconds}s left';
    final mins = seconds ~/ 60;
    final rem = seconds % 60;
    return '${mins}m ${rem}s left';
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(downloadQueueProvider);
    final activeItems = items.where((e) => e.isActive).toList();
    final historyItems = items.where((e) => e.isFinished).toList();
    final displayed = _showHistory ? historyItems : activeItems;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Downloads',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_showHistory && historyItems.isNotEmpty)
                  TextButton.icon(
                    key: const Key('downloads_clear_history_button'),
                    onPressed: () {
                      ref.read(downloadQueueProvider.notifier).clearFinished();
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(
                      'Active (${activeItems.length})',
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    icon: const Icon(Icons.downloading_rounded),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(
                      'History (${historyItems.length})',
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    icon: const Icon(Icons.history_rounded),
                  ),
                ],
                selected: {_showHistory},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    setState(() {
                      _showHistory = selection.first;
                    });
                  }
                },
              ),
            ),
          ),
          Expanded(
            child: displayed.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showHistory
                                ? Icons.inventory_2_outlined
                                : Icons.cloud_download_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _showHistory
                                ? 'No completed downloads yet'
                                : 'No active downloads',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Paste a TikTok, Instagram, or YouTube URL on Home, or share directly from the Android Share Sheet.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: displayed.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = displayed[index];
                      return _QueueItemCard(
                        item: item,
                        bytesLabel: _formatBytes(
                          item.totalBytes ?? item.downloadedBytes,
                        ),
                        speedLabel: _formatSpeed(item.speedBps),
                        etaLabel: _formatEta(item.etaSeconds),
                        onCancel: () {
                          ref
                              .read(downloadQueueProvider.notifier)
                              .cancelTask(item.id);
                        },
                        onRetry: () {
                          ref
                              .read(downloadQueueProvider.notifier)
                              .retryTask(item.id);
                        },
                        onDelete: () {
                          ref
                              .read(downloadQueueProvider.notifier)
                              .deleteTask(item.id);
                        },
                        onOpen: () async {
                          final target = item.contentUri ?? item.outputPath;
                          if (target == null) return;
                          final ok = await ref
                              .read(androidPlatformProvider)
                              .openFile(target);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No app available to open file'),
                              ),
                            );
                          }
                        },
                        onShare: () async {
                          final target = item.contentUri ?? item.outputPath;
                          if (target == null) return;
                          await ref
                              .read(androidPlatformProvider)
                              .shareFile(target);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueueItemCard extends StatelessWidget {
  const _QueueItemCard({
    required this.item,
    required this.bytesLabel,
    required this.speedLabel,
    required this.etaLabel,
    required this.onCancel,
    required this.onRetry,
    required this.onDelete,
    required this.onOpen,
    required this.onShare,
  });

  final QueueItem item;
  final String bytesLabel;
  final String speedLabel;
  final String etaLabel;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onDelete;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final phaseColor = switch (item.phase) {
      DownloadPhase.completed => KlipFetchTheme.successTone.ink,
      DownloadPhase.failed => scheme.error,
      DownloadPhase.cancelled => scheme.onSurfaceVariant,
      _ => scheme.primary,
    };

    final metricParts = [
      if (item.isActive && item.progress > 0) '${item.progress.round()}%',
      if (speedLabel.isNotEmpty) speedLabel,
      if (etaLabel.isNotEmpty) etaLabel,
      if (bytesLabel.isNotEmpty) bytesLabel,
      if (item.qualityLabel != null && item.qualityLabel!.isNotEmpty)
        item.qualityLabel == 'best' ? 'Best' : item.qualityLabel!,
      if (item.exportedCount > 1) '${item.exportedCount} files',
    ];

    return Card(
      key: Key('queue_card_${item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlatformBadge(platform: item.platform, compact: true),
                const SizedBox(width: 6),
                EngineBadge(
                  engine: item.engine,
                  usedFallback: item.usedFallback,
                ),
                const Spacer(),
                Text(
                  item.phase.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: phaseColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (metricParts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: metricParts
                    .map(
                      (part) => Text(
                        part,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (item.isActive) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: item.progress > 0
                      ? (item.progress / 100.0).clamp(0.0, 1.0)
                      : null,
                  minHeight: 6,
                ),
              ),
            ],
            if (item.phase == DownloadPhase.completed &&
                item.outputPath != null &&
                item.outputPath!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.outputPath!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KlipFetchTheme.successTone.ink,
                ),
              ),
            ],
            if (item.phase == DownloadPhase.failed &&
                item.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                item.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.isActive)
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Cancel'),
                  ),
                if (item.phase == DownloadPhase.failed ||
                    item.phase == DownloadPhase.cancelled) ...[
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Remove'),
                  ),
                ],
                if (item.phase == DownloadPhase.completed) ...[
                  if (item.contentUri != null || item.outputPath != null) ...[
                    TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Open'),
                    ),
                    TextButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Remove from history',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
