// lib/src/paystack_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_paystack_modal/src/widgets/payment_button.dart';
import 'package:provider/provider.dart';
import 'models/paystack_config.dart';
import 'models/payment_state.dart';
import 'providers/paystack_provider.dart';
import 'widgets/payment_summary_card.dart';

/// Public-facing widget. Owns the [ChangeNotifierProvider] lifetime
/// and passes display-only data (title, description) down to the
/// inner content widget.
///
/// Business logic: [PaystackProvider]
/// UI shell:       [_SheetContent]
/// Card UI:        [PaymentSummaryCard]
/// Button UI:      [PayButton]
class PaystackBottomSheet extends StatelessWidget {
  final PaystackConfig config;
  final String? title;
  final String? description;
  final VoidCallback? onClosed;
  final Future<void> Function(String reference)? onVerify;
  final void Function(String reference)? onSuccess;

  const PaystackBottomSheet({
    super.key,
    required this.config,
    this.title,
    this.description,
    this.onClosed,
    this.onVerify,
    this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PaystackProvider(
        config: config,
        onVerify: onVerify,
        onSuccess: onSuccess,
        onClosed: onClosed,
      ),
      child: _SheetContent(
        title: title,
        description: description,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inner content widget — StatefulWidget so it can register a provider
// listener once in initState and react to errors as a side-effect
// (showing a SnackBar) without mixing that logic into build().
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
    // Read once — we only need the reference, not a rebuild from this.
    _provider = context.read<PaystackProvider>();
    // Listen for errors as a side-effect, separate from build().
    _provider.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  /// Reacts to state changes that require a side-effect (SnackBar).
  /// Keeps build() clean — errors are handled here, not in the widget tree.
  void _onProviderUpdate() {
    final state = _provider.state;
    if (state is PaymentError) {
      // Schedule after the current frame so the widget tree is stable.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Reset to idle so the same error isn't shown again on next rebuild.
        _provider.clearError();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch rebuilds this widget on every provider notification.
    final provider = context.watch<PaystackProvider>();
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return PopScope(
      // Block swipe-to-dismiss while any async operation is running.
      canPop: !provider.isLoading,
      onPopInvokedWithResult: (didPop, dynamic) {
        if (didPop) provider.handleUserDismiss();
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
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
            const SizedBox(height: 24),

            // ── Title ──────────────────────────────────────────────────────
            Text(
              widget.title ?? 'Complete Payment',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            if (widget.description != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.description!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],

            const SizedBox(height: 24),

            // ── Payment summary card ───────────────────────────────────────
            PaymentSummaryCard(config: provider.config),

            // ── Cloud function badge ───────────────────────────────────────
            if (provider.config.isCloudFunctionMode) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.cloud_done_outlined,
                      size: 13, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    'Initialized via secure backend',
                    style: TextStyle(
                        fontSize: 11, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // ── Pay button — reads provider internally ─────────────────────
            const PayButton(),

            const SizedBox(height: 12),

            // ── Paystack security badge ────────────────────────────────────
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      size: 13, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    'Secured by Paystack',
                    style: TextStyle(
                        color: theme.colorScheme.outline, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}