import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/queue_item.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/editorial_controls.dart';
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

    return SafeArea(
      child: Column(
        children: [
          EditorialMasthead(
            title: 'Downloads',
            trailing: (_showHistory && historyItems.isNotEmpty)
                ? TextButton(
                    key: const Key('downloads_clear_history_button'),
                    style: TextButton.styleFrom(
                      foregroundColor: KlipFetchTheme.lightError,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: () {
                      ref.read(downloadQueueProvider.notifier).clearFinished();
                    },
                    child: const Text('Clear'),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: EditorialSegmentedControl<bool>(
              tabular: true,
              options: [
                EditorialSegmentOption(
                  value: false,
                  label: 'Active (${activeItems.length})',
                ),
                EditorialSegmentOption(
                  value: true,
                  label: 'History (${historyItems.length})',
                ),
              ],
              selected: _showHistory,
              onSelected: (value) {
                setState(() {
                  _showHistory = value;
                });
              },
            ),
          ),
          Expanded(
            child: displayed.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: EditorialWell(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _showHistory
                                  ? 'No completed downloads yet'
                                  : 'No active downloads',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Paste a TikTok, Instagram, or YouTube URL on Home, or share directly from the Android Share Sheet.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: KlipFetchTheme.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    itemCount:
                        displayed.length + (!_showHistory ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == displayed.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            'Active downloads run in a foreground service so transfers continue when the screen turns off.',
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }
                      final item = displayed[index];
                      return _QueueLedgerRow(
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

class _QueueLedgerRow extends StatelessWidget {
  const _QueueLedgerRow({
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

    final phaseColor = switch (item.phase) {
      DownloadPhase.completed => KlipFetchTheme.successTone.ink,
      DownloadPhase.failed => KlipFetchTheme.lightError,
      DownloadPhase.cancelled => KlipFetchTheme.lightMutedInk,
      _ => KlipFetchTheme.brandAccent,
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

    return Container(
      key: Key('queue_card_${item.id}'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: KlipFetchTheme.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlatformBadge(platform: item.platform, compact: true),
              const SizedBox(width: 8),
              EngineBadge(
                engine: item.engine,
                usedFallback: item.usedFallback,
              ),
              const Spacer(),
              Text(
                item.phase.label,
                style: TextStyle(
                  fontFamily: KlipFetchTheme.bodyFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: phaseColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          if (item.isActive) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: item.progress > 0
                  ? (item.progress / 100.0).clamp(0.0, 1.0)
                  : null,
              minHeight: 4,
            ),
          ],
          if (item.phase == DownloadPhase.completed &&
              item.outputPath != null &&
              item.outputPath!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.outputPath!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KlipFetchTheme.monoStyle(
                size: 11.5,
                color: KlipFetchTheme.successTone.ink,
              ),
            ),
          ],
          if (item.phase == DownloadPhase.failed &&
              item.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              item.errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: KlipFetchTheme.bodyFontFamily,
                fontSize: 12,
                color: KlipFetchTheme.lightError,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  metricParts.join('   '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KlipFetchTheme.monoStyle(size: 11.5),
                ),
              ),
              const SizedBox(width: 12),
              if (item.isActive)
                _InlineLedgerAction(
                  label: 'Cancel',
                  color: KlipFetchTheme.inkSecondary,
                  onTap: onCancel,
                ),
              if (item.phase == DownloadPhase.failed ||
                  item.phase == DownloadPhase.cancelled) ...[
                _InlineLedgerAction(
                  label: 'Retry',
                  color: item.phase == DownloadPhase.failed
                      ? KlipFetchTheme.brandAccent
                      : KlipFetchTheme.lightInk,
                  onTap: onRetry,
                ),
                const SizedBox(width: 14),
                _InlineLedgerAction(
                  label: 'Remove',
                  color: KlipFetchTheme.lightError,
                  onTap: onDelete,
                ),
              ],
              if (item.phase == DownloadPhase.completed) ...[
                if (item.contentUri != null || item.outputPath != null) ...[
                  _InlineLedgerAction(
                    label: 'Open',
                    color: KlipFetchTheme.lightInk,
                    onTap: onOpen,
                  ),
                  const SizedBox(width: 14),
                  _InlineLedgerAction(
                    label: 'Share',
                    color: KlipFetchTheme.inkSecondary,
                    onTap: onShare,
                  ),
                  const SizedBox(width: 10),
                ],
                InkResponse(
                  radius: 18,
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: KlipFetchTheme.lightError,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineLedgerAction extends StatelessWidget {
  const _InlineLedgerAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(2),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: KlipFetchTheme.bodyFontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
