// lib/src/paystack_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'paystack_config.dart';

class PaystackBottomSheet extends StatefulWidget {
  final PaystackConfig config;
  final String? title;
  final String? description;

  /// Called when the user dismisses without paying
  final VoidCallback? onClosed;

  /// Called after a successful payment with the transaction reference.
  /// Use this to call your verification cloud function.
  /// If this Future throws, an error snackbar is shown.
  final Future<void> Function(String reference)? onVerify;

  /// Called after onVerify completes successfully.
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
  State<PaystackBottomSheet> createState() => _PaystackBottomSheetState();
}

class _PaystackBottomSheetState extends State<PaystackBottomSheet> {
  /// True while the Paystack popup is launching or verification is running
  bool _isLoading = false;

  /// Status message shown on the button during multi-step flow
  String _statusMessage = '';

  /// True when WE triggered the pop programmatically (success, Paystack cancel).
  /// False when the USER dismissed the sheet by swiping or tapping the barrier.
  /// Prevents onClosed from being called twice.
  bool _closedByCode = false;

  Future<void> _initiatePayment() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening payment...';
    });

    try {
      await FlutterPaystackPlus.openPaystackPopup(
        context: context,
        publicKey: widget.config.publicKey,

        // ── Cloud function mode: use pre-fetched URL ──────────────────────────
        // ── Direct keys mode:   use secret key ───────────────────────────────
        authorizationUrl: widget.config.authorizationUrl,
        secretKey: widget.config.secretKey,

        customerEmail: widget.config.email,
        reference: widget.config.reference,
        amount: widget.config.amountInSubunit.toString(),
        currency: widget.config.currency,

        onClosed: () {
          // User closed the Paystack webview popup without paying.
          // Mark as code-initiated so PopScope doesn't fire onClosed again.
          _closedByCode = true;
          if (mounted) Navigator.of(context).pop();
          widget.onClosed?.call();
        },

        onSuccess: () async {
          await _handleVerification(widget.config.reference);
        },
      );
    } catch (e) {
      _showError('Failed to open payment: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerification(String reference) async {
    // If no verify callback is registered, just fire onSuccess directly
    if (widget.onVerify == null) {
      _closedByCode = true;
      if (mounted) Navigator.of(context).pop();
      widget.onSuccess?.call(reference);
      return;
    }

    // Show verification loading state
    if (mounted) {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Verifying payment...';
      });
    }

    try {
      await widget.onVerify!(reference);

      // Verification passed ✅
      _closedByCode = true;
      if (mounted) Navigator.of(context).pop();
      widget.onSuccess?.call(reference);
    } catch (e) {
      _showError('Payment verification failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return PopScope(
      // Prevent swipe-to-dismiss while payment or verification is in progress
      canPop: !_isLoading,
      onPopInvokedWithResult: (didPop, dynamic) {
        // Only fire onClosed when the USER dismissed the sheet (swipe/back),
        // not when our own code called Navigator.pop().
        if (didPop && !_closedByCode) {
          widget.onClosed?.call();
        }
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
          // Drag handle
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

          // Title
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

          // Payment summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _DetailRow(label: 'Email', value: widget.config.email),
                const Divider(height: 20),
                _DetailRow(
                  label: 'Reference',
                  value: widget.config.reference,
                  valueMaxLines: 1,
                ),
                const Divider(height: 20),
                _DetailRow(
                  label: 'Amount',
                  value: widget.config.formattedAmount,
                  valueStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Show a subtle cloud badge if using cloud function mode
          if (widget.config.isCloudFunctionMode) ...[
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

          // Pay button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _initiatePayment,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _statusMessage,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    )
                  : Text(
                      'Pay ${widget.config.formattedAmount}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          const SizedBox(height: 12),
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
    ),   // closes Container (child of PopScope)
    );   // closes PopScope
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final int? valueMaxLines;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueStyle,
    this.valueMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: valueStyle ?? theme.textTheme.bodyMedium,
            textAlign: TextAlign.right,
            maxLines: valueMaxLines,
            overflow: valueMaxLines != null
                ? TextOverflow.ellipsis
                : TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}
