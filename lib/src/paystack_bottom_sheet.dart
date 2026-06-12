// lib/src/paystack_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/payment_state.dart';
import 'models/paystack_config.dart';
import 'providers/paystack_provider.dart';
import 'widgets/paystack_webview.dart';

class PaystackBottomSheet extends StatelessWidget {
  final PaystackConfig config;
  final String? title;
  final String? description;
  final void Function()? onClosed;
  final Future<void> Function(String reference)? onVerify;
  final void Function(String reference)? onSuccess;
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
      child: _SheetContent(title: title, description: description),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SheetContent extends StatefulWidget {
  final String? title;
  final String? description;
  const _SheetContent({this.title, this.description});

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent>
    with SingleTickerProviderStateMixin {
  late final PaystackProvider _provider;
  late final AnimationController _successAnim;

  @override
  void initState() {
    super.initState();
    _provider = context.read<PaystackProvider>();
    _provider.addListener(_onStateChange);

    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _provider.removeListener(_onStateChange);
    _successAnim.dispose();
    super.dispose();
  }

  void _onStateChange() {
    final state = _provider.state;

    if (state is PaymentSuccess) {
      _successAnim.forward();
      // Fire onSuccess immediately so callers awaiting showPaystackPayment()
      // see the result before the future resolves. Pop happens after the
      // animation for visual polish, but the callback can't wait for that.
      _provider.fireSuccessCallback();

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    }

    if (state is PaymentCancelled) {
      _provider.fireClosedCallback();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    }

    if (state is PaymentError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
        _provider.clearError();
      });
    }
  }

  void _dismiss() {
    _provider.handleUserDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaystackProvider>();
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return PopScope(
      canPop: !provider.isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _dismiss();
      },
      child: Container(
        height: mq.size.height * 0.92,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _SheetHeader(
              title: widget.title,
              description: widget.description,
              config: provider.config,
              isLoading: provider.isLoading,
              onClose: _dismiss,
            ),
            Expanded(child: PaystackWebView(successAnim: _successAnim)),
            _SheetFooter(isAuthMode: provider.config.isAuthUrlMode),
            SizedBox(height: mq.padding.bottom),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final String? title;
  final String? description;
  final PaystackConfig config;
  final bool isLoading;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.title,
    required this.description,
    required this.config,
    required this.isLoading,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Paystack logo mark
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C3F7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      '₦',
                      style: TextStyle(
                        color: Color(0xFF0BA4DB),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? 'Complete Payment',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (description != null)
                        Text(
                          description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),

                // Amount badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0BA4DB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    config.formattedAmount,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF0BA4DB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Close button — hidden while loading
                if (!isLoading)
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 20, color: theme.colorScheme.outline),
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          ),

          // Thin divider
          const SizedBox(height: 10),
          Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ],
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

class _SheetFooter extends StatelessWidget {
  final bool isAuthMode;
  const _SheetFooter({required this.isAuthMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 12, color: theme.colorScheme.outline),
          const SizedBox(width: 5),
          Text(
            isAuthMode
                ? 'Secured by Paystack · Backend-verified'
                : 'Secured by Paystack',
            style: TextStyle(
              color: theme.colorScheme.outline,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
