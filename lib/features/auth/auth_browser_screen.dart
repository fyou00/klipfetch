import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/auth_models.dart';
import '../../models/media_platform.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/platform_badge.dart';

class AuthBrowserScreen extends ConsumerStatefulWidget {
  const AuthBrowserScreen({super.key});

  @override
  ConsumerState<AuthBrowserScreen> createState() => _AuthBrowserScreenState();
}

class _AuthBrowserScreenState extends ConsumerState<AuthBrowserScreen> {
  final Set<MediaPlatform> _busyPlatforms = <MediaPlatform>{};
  final Map<MediaPlatform, SessionTestResult> _testResults =
      <MediaPlatform, SessionTestResult>{};

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(() async {
        try {
          await ref.read(cookieStatusesProvider.notifier).refresh();
        } catch (_) {
          // Ignore when native FFI is unavailable in pure widget tests.
        }
      }),
    );
  }

  Future<void> _signIn(AuthPlatformConfig config) async {
    setState(() {
      _busyPlatforms.add(config.platform);
      _testResults.remove(config.platform);
    });
    try {
      final updated =
          await ref.read(cookieStatusesProvider.notifier).signIn(config.platform);
      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${config.label} sign-in cancelled')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updated.isConnected
                  ? '${config.label} session saved (${updated.cookieCount} cookies)'
                  : 'Captured ${updated.cookieCount} cookies for ${config.label}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save ${config.label} cookies: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPlatforms.remove(config.platform);
        });
      }
    }
  }

  Future<void> _testSession(AuthPlatformConfig config) async {
    setState(() {
      _busyPlatforms.add(config.platform);
    });
    try {
      final result = await ref
          .read(cookieStatusesProvider.notifier)
          .testSession(config.platform);
      if (!mounted) return;
      setState(() {
        _testResults[config.platform] = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testResults[config.platform] = SessionTestResult(
          platform: config.platform,
          isValid: false,
          message: 'Session check failed: $e',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyPlatforms.remove(config.platform);
        });
      }
    }
  }

  Future<void> _importCookies(AuthPlatformConfig config) async {
    final controller = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Import ${config.label} cookies.txt'),
          content: TextField(
            key: const Key('auth_import_input'),
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '# Netscape HTTP Cookie File\n...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('auth_import_save_button'),
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (submitted == null || submitted.trim().isEmpty || !mounted) return;

    setState(() {
      _busyPlatforms.add(config.platform);
      _testResults.remove(config.platform);
    });
    try {
      final status = await ref
          .read(cookieStatusesProvider.notifier)
          .importNetscape(config.platform, submitted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${status.cookieCount} cookies for ${config.label}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid Netscape cookies: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPlatforms.remove(config.platform);
        });
      }
    }
  }

  Future<void> _clearCookies(AuthPlatformConfig config) async {
    setState(() {
      _busyPlatforms.add(config.platform);
      _testResults.remove(config.platform);
    });
    try {
      await ref.read(cookieStatusesProvider.notifier).clear(config.platform);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleared ${config.label} cookies')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear ${config.label} cookies: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPlatforms.remove(config.platform);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ref.watch(cookieStatusesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts & Cookies'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sign in via Android WebView to capture HttpOnly session cookies for Stories, private posts, and age-restricted videos. Cookies are stored only inside app-private storage.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final config in AuthPlatformConfig.all) ...[
            _PlatformAuthCard(
              config: config,
              status: statuses[config.platform] ??
                  CookieSessionStatus(
                    platform: config.platform,
                    domain: config.domain,
                  ),
              isBusy: _busyPlatforms.contains(config.platform),
              testResult: _testResults[config.platform],
              onSignIn: () => _signIn(config),
              onTest: () => _testSession(config),
              onImport: () => _importCookies(config),
              onClear: () => _clearCookies(config),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PlatformAuthCard extends StatelessWidget {
  const _PlatformAuthCard({
    required this.config,
    required this.status,
    required this.isBusy,
    required this.testResult,
    required this.onSignIn,
    required this.onTest,
    required this.onImport,
    required this.onClear,
  });

  final AuthPlatformConfig config;
  final CookieSessionStatus status;
  final bool isBusy;
  final SessionTestResult? testResult;
  final VoidCallback onSignIn;
  final VoidCallback onTest;
  final VoidCallback onImport;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (statusLabel, statusTone) = switch ((
      status.hasCookies,
      status.hasAuthCookie,
    )) {
      (true, true) => ('Connected', KlipFetchTheme.successTone),
      (true, false) => ('Incomplete', KlipFetchTheme.warningTone),
      _ => ('Not signed in', KlipFetchTheme.neutralTone),
    };
    final resultTone = testResult == null
        ? null
        : (testResult!.isValid
            ? KlipFetchTheme.successTone
            : KlipFetchTheme.errorTone);

    return Card(
      key: Key('auth_card_${config.platform.name}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlatformBadge(platform: config.platform, compact: true),
                const SizedBox(width: 8),
                Text(
                  config.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusTone.fill,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusTone.border),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      color: statusTone.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status.hasCookies
                  ? '${status.cookieCount} cookies saved in ${config.domain}'
                  : config.helperNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (testResult != null && resultTone != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: resultTone.fill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: resultTone.border),
                ),
                child: Text(
                  testResult!.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: Key('auth_signin_${config.platform.name}'),
                  onPressed: isBusy ? null : onSignIn,
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded, size: 18),
                  label: Text(status.isConnected ? 'Re-auth' : 'Sign In'),
                ),
                OutlinedButton.icon(
                  key: Key('auth_test_${config.platform.name}'),
                  onPressed: isBusy ? null : onTest,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Test'),
                ),
                TextButton.icon(
                  key: Key('auth_import_${config.platform.name}'),
                  onPressed: isBusy ? null : onImport,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Import'),
                ),
                if (status.hasCookies)
                  TextButton.icon(
                    key: Key('auth_clear_${config.platform.name}'),
                    onPressed: isBusy ? null : onClear,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
