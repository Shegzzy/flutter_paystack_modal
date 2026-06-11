// lib/src/widgets/paystack_webview.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/payment_state.dart';
import '../providers/paystack_provider.dart';

/// The WebView area in the bottom sheet.
/// Shows:
///   - A loading spinner while the page loads
///   - The WebView once ready
///   - A verifying overlay while calling your backend
///   - An error screen with a Retry button
class PaystackWebView extends StatelessWidget {
  const PaystackWebView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaystackProvider>();
    final state = provider.state;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (state) {
        PaymentError(:final message) => _ErrorView(
            key: const ValueKey('error'),
            message: message,
            onRetry: provider.retry,
          ),
        PaymentSuccess() => _SuccessView(key: const ValueKey('success')),
        PaymentCancelled() => const SizedBox.shrink(),
        _ => Stack(
            key: const ValueKey('webview'),
            children: [
              if (provider.webViewController != null)
                WebViewWidget(controller: provider.webViewController!),
              if (state is PaymentLoading)
                const _LoadingOverlay(message: 'Loading payment page…'),
              if (state is PaymentVerifying)
                const _LoadingOverlay(message: 'Verifying payment…'),
            ],
          ),
      },
    );
  }
}

// ─── Overlays ─────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  final String message;
  const _LoadingOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 56, color: Colors.green.shade600),
            const SizedBox(height: 16),
            Text(
              'Payment Successful',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Your transaction has been confirmed.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
