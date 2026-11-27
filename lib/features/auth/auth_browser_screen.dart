import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/auth_models.dart';
import '../../models/media_platform.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/editorial_controls.dart';
import '../../widgets/platform_badge.dart';

class AuthBrowserScreen extends ConsumerStatefulWidget {
  const AuthBrowserScreen({super.key});

  @override
  ConsumerState<AuthBrowserScreen> createState() => _AuthBrowserScreenState();
}

class _AuthBrowserScreenState extends ConsumerState<AuthBrowserScreen> {
  final Set<MediaPlatform> _busyPlatforms = {};
  final Map<MediaPlatform, SessionTestResult> _testResults = {};

  void _setBusy(MediaPlatform platform, bool busy) {
    if (!mounted) return;
    setState(() {
      if (busy) {
        _busyPlatforms.add(platform);
      } else {
        _busyPlatforms.remove(platform);
      }
    });
  }

  Future<void> _signIn(AuthPlatformConfig config) async {
    _setBusy(config.platform, true);
    try {
      final status =
          await ref.read(cookieStatusesProvider.notifier).signIn(config.platform);
      if (!mounted) return;
      if (status != null) {
        setState(() {
          _testResults.remove(config.platform);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status.isConnected
                  ? '${config.label} session saved (${status.cookieCount} cookies).'
                  : 'Saved ${status.cookieCount} cookies for ${config.label}. Sign-in may still be incomplete.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $error')),
      );
    } finally {
      _setBusy(config.platform, false);
    }
  }

  Future<void> _testSession(AuthPlatformConfig config) async {
    _setBusy(config.platform, true);
    try {
      final result = await ref
          .read(cookieStatusesProvider.notifier)
          .testSession(config.platform);
      if (!mounted) return;
      setState(() {
        _testResults[config.platform] = result;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session verification failed: $error')),
      );
    } finally {
      _setBusy(config.platform, false);
    }
  }

  Future<void> _importCookies(AuthPlatformConfig config) async {
    final controller = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Import ${config.label} cookies.txt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste Netscape-format cookies exported from an authenticated ${config.label} browser session.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('auth_import_input'),
              controller: controller,
              minLines: 4,
              maxLines: 7,
              style: KlipFetchTheme.monoStyle(size: 12),
              decoration: InputDecoration(
                hintText: '# Netscape HTTP Cookie File\n.${config.domain}\t...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('auth_import_save_button'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (submitted == null || submitted.trim().isEmpty || !mounted) return;

    _setBusy(config.platform, true);
    try {
      final status = await ref
          .read(cookieStatusesProvider.notifier)
          .importNetscape(config.platform, submitted);
      if (!mounted) return;
      setState(() {
        _testResults.remove(config.platform);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${status.cookieCount} cookies for ${config.label}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cookie import failed: $error')),
      );
    } finally {
      _setBusy(config.platform, false);
    }
  }

  Future<void> _clearCookies(AuthPlatformConfig config) async {
    _setBusy(config.platform, true);
    try {
      await ref.read(cookieStatusesProvider.notifier).clear(config.platform);
      if (!mounted) return;
      setState(() {
        _testResults.remove(config.platform);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleared ${config.label} session cookies.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear cookies: $error')),
      );
    } finally {
      _setBusy(config.platform, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = ref.watch(cookieStatusesProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            EditorialMasthead(
              title: 'Accounts & Cookies',
              titleSize: 22,
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: KlipFetchTheme.lightInk,
              ),
            ),
            const SizedBox(height: 14),
            EditorialWell(
              fillColor: KlipFetchTheme.lightSurfaceSubtle,
              borderColor: KlipFetchTheme.lightBorder,
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: KlipFetchTheme.inkSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Private session vault',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: KlipFetchTheme.lightInk,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Cookies captured via native WebView or pasted as Netscape cookies.txt stay in app-private storage (cookies/cookies.txt) and are never logged or shared.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KlipFetchTheme.inkSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < AuthPlatformConfig.all.length; i++) ...[
              _buildPlatformCard(
                context,
                config: AuthPlatformConfig.all[i],
                status: statuses[AuthPlatformConfig.all[i].platform] ??
                    CookieSessionStatus(
                      platform: AuthPlatformConfig.all[i].platform,
                      domain: AuthPlatformConfig.all[i].domain,
                    ),
              ),
              if (i < AuthPlatformConfig.all.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformCard(
    BuildContext context, {
    required AuthPlatformConfig config,
    required CookieSessionStatus status,
  }) {
    final theme = Theme.of(context);
    final isBusy = _busyPlatforms.contains(config.platform);
    final testResult = _testResults[config.platform];

    final (statusLabel, statusTone) =
        switch ((status.hasCookies, status.hasAuthCookie)) {
      (true, true) => ('Connected', KlipFetchTheme.successTone),
      (true, false) => ('Incomplete', KlipFetchTheme.warningTone),
      _ => ('Not signed in', KlipFetchTheme.neutralTone),
    };

    final cookieSummary = status.hasCookies
        ? '${status.cookieCount} cookies stored'
        : 'No local cookies stored';

    final ButtonStyle compactButtonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Material(
      key: Key('auth_card_${config.platform.name}'),
      color: KlipFetchTheme.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: KlipFetchTheme.lightBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlatformBadge(platform: config.platform),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config.domain,
                    overflow: TextOverflow.ellipsis,
                    style: KlipFetchTheme.monoStyle(
                      size: 11.5,
                      color: KlipFetchTheme.lightMutedInk,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                EditorialStatusTag(
                  label: statusLabel,
                  tone: statusTone,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              config.helperNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: KlipFetchTheme.inkSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cookieSummary,
              style: KlipFetchTheme.monoStyle(
                size: 11.5,
                color: status.hasCookies
                    ? KlipFetchTheme.inkSecondary
                    : KlipFetchTheme.lightMutedInk,
              ),
            ),
            if (testResult != null) ...[
              const SizedBox(height: 10),
              _buildTestResultBanner(theme, testResult),
            ],
            const SizedBox(height: 12),
            const EditorialHairline(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!status.isConnected)
                  FilledButton(
                    key: Key('auth_signin_${config.platform.name}'),
                    style: compactButtonStyle,
                    onPressed: isBusy ? null : () => _signIn(config),
                    child: const Text('Sign In'),
                  )
                else
                  OutlinedButton(
                    key: Key('auth_signin_${config.platform.name}'),
                    style: compactButtonStyle,
                    onPressed: isBusy ? null : () => _signIn(config),
                    child: const Text('Re-auth'),
                  ),
                OutlinedButton(
                  key: Key('auth_test_${config.platform.name}'),
                  style: compactButtonStyle,
                  onPressed: (isBusy || !status.hasCookies)
                      ? null
                      : () => _testSession(config),
                  child: const Text('Test'),
                ),
                OutlinedButton(
                  key: Key('auth_import_${config.platform.name}'),
                  style: compactButtonStyle,
                  onPressed: isBusy ? null : () => _importCookies(config),
                  child: const Text('Import'),
                ),
                if (status.hasCookies)
                  TextButton(
                    key: Key('auth_clear_${config.platform.name}'),
                    style: compactButtonStyle.copyWith(
                      foregroundColor: const WidgetStatePropertyAll(
                        KlipFetchTheme.lightError,
                      ),
                    ),
                    onPressed: isBusy ? null : () => _clearCookies(config),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultBanner(ThemeData theme, SessionTestResult result) {
    final tone =
        result.isValid ? KlipFetchTheme.successTone : KlipFetchTheme.errorTone;
    return EditorialWell(
      fillColor: tone.fill,
      borderColor: tone.border,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            result.isValid
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            size: 15,
            color: tone.ink,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tone.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
