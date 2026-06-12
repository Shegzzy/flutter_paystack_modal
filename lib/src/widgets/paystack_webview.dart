// lib/src/widgets/paystack_webview.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/payment_state.dart';
import '../providers/paystack_provider.dart';

class PaystackWebView extends StatelessWidget {
  final AnimationController successAnim;
  const PaystackWebView({super.key, required this.successAnim});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaystackProvider>();
    final state = provider.state;

    return Stack(
      children: [
        // WebView always mounted so it doesn't reload on state changes
        if (provider.webViewController != null)
          WebViewWidget(controller: provider.webViewController!),

        // Overlays on top
        if (state is PaymentLoading)
          _LoadingOverlay(key: const ValueKey('loading')),

        if (state is PaymentVerifying)
          _VerifyingOverlay(key: const ValueKey('verifying')),

        if (state is PaymentSuccess)
          _SuccessOverlay(
            key: const ValueKey('success'),
            animation: successAnim,
            reference: state.reference,
          ),

        if (state is PaymentError)
          _ErrorOverlay(
            key: const ValueKey('error'),
            message: state.message,
            onRetry: provider.retry,
          ),
      ],
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: const Color(0xFF0BA4DB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading secure payment…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Verifying ────────────────────────────────────────────────────────────────

class _VerifyingOverlay extends StatelessWidget {
  const _VerifyingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: const Color(0xFF0BA4DB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Verifying your payment…',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please wait, do not close this screen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Success ──────────────────────────────────────────────────────────────────

class _SuccessOverlay extends StatelessWidget {
  final AnimationController animation;
  final String reference;
  const _SuccessOverlay({
    super.key,
    required this.animation,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scale = Tween<double>(begin: 0.7, end: 1.0)
                .animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.elasticOut,
                ))
                .value;
            final opacity = Tween<double>(begin: 0.0, end: 1.0)
                .animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.4),
                ))
                .value;

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF22C55E),
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Payment Successful',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your transaction has been confirmed.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ref: $reference',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _ErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorOverlay({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: theme.colorScheme.error,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Problem',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0BA4DB),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
