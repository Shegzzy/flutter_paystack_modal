// lib/src/paystack_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/payment_state.dart';
import 'models/paystack_config.dart';
import 'providers/paystack_provider.dart';
import 'widgets/payment_summary_card.dart';
import 'widgets/paystack_webview.dart';

/// Public-facing widget. Owns the [ChangeNotifierProvider] lifetime.
///
/// Business logic:  [PaystackProvider]
/// Summary card:    [PaymentSummaryCard]
/// WebView area:    [PaystackWebView]
class PaystackBottomSheet extends StatelessWidget {
  final PaystackConfig config;
  final String? title;
  final String? description;

  /// Called when user closes the sheet without completing payment.
  final void Function()? onClosed;

  /// Called after Paystack confirms success. Use this to call your backend.
  /// Throw to signal failure — the sheet will show an error + retry.
  final Future<void> Function(String reference)? onVerify;

  /// Called after [onVerify] completes (or immediately if no [onVerify]).
  final void Function(String reference)? onSuccess;

  /// Called on any error (network, verification failure, etc.).
  final void Function(String error)? onError;

  const PaystackBottomSheet({
    super.key,
    required this.config,
    this.title,
    this.description,
    this.onClosed,
    this.onVerify,
    this.onSuccess,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PaystackProvider(
        config: config,
        onVerify: onVerify,
        onSuccess: onSuccess,
        onClosed: onClosed,
        onError: onError,
      ),
      child: _SheetContent(
        title: title,
        description: description,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inner content — StatefulWidget so it can listen for errors as a side-effect
// (SnackBar) and auto-close the sheet after success.
// ─────────────────────────────────────────────────────────────────────────────

class _SheetContent extends StatefulWidget {
  final String? title;
  final String? description;

  const _SheetContent({this.title, this.description});

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent> {
  late final PaystackProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<PaystackProvider>();
    _provider.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    final state = _provider.state;

    // Show error in a SnackBar then reset so it doesn't show again.
    if (state is PaymentError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _provider.clearError();
      });
    }

    // Auto-close the sheet a beat after success so user sees the tick.
    if (state is PaymentSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.of(context).pop();
        });
      });
    }

    // Close immediately on cancel.
    if (state is PaymentCancelled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaystackProvider>();
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !provider.isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) provider.handleUserDismiss();
      },
      child: Container(
        // Take up most of the screen so the WebView has room.
        height: MediaQuery.of(context).size.height * 0.9,
        padding: EdgeInsets.fromLTRB(0, 12, 0, bottomPadding),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title ?? 'Complete Payment',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Close button
                      if (!provider.isLoading)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            provider.handleUserDismiss();
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                  if (widget.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.description!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Payment summary ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PaymentSummaryCard(config: provider.config),
            ),

            if (provider.config.isAuthUrlMode) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(height: 6),
                    Icon(Icons.cloud_done_outlined,
                        size: 12, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      'Secured via backend',
                      style: TextStyle(
                          fontSize: 11, color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── WebView — takes all remaining space ───────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: const PaystackWebView(),
              ),
            ),

            // ── Paystack badge ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 8),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 12, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      'Secured by Paystack',
                      style: TextStyle(
                          color: theme.colorScheme.outline, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
