// lib/src/providers/paystack_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import '../models/paystack_config.dart';
import '../models/payment_state.dart';

/// Owns every state transition in the payment flow.
/// The UI reads from this and calls [initiatePayment]; it never
/// calls flutter_paystack_plus or your cloud functions directly.
class PaystackProvider extends ChangeNotifier {
  final PaystackConfig config;

  /// Called right after Paystack confirms charge.
  /// Throw here to signal verification failure — the provider
  /// catches it and transitions to [PaymentError].
  final Future<void> Function(String reference)? onVerify;

  /// Called after [onVerify] completes (or immediately if no [onVerify]).
  final void Function(String reference)? onSuccess;

  /// Called when the user dismisses the sheet without paying.
  final VoidCallback? onClosed;

  PaystackProvider({
    required this.config,
    this.onVerify,
    this.onSuccess,
    this.onClosed,
  });

  // ─── State ────────────────────────────────────────────────────────────────

  PaymentState _state = const PaymentIdle();
  PaymentState get state => _state;

  /// True when any async operation is in progress.
  /// The UI uses this to block swipe-dismiss and disable the button.
  bool get isLoading =>
      _state is PaymentOpening || _state is PaymentVerifying;

  /// Set to true before WE call Navigator.pop() so PopScope knows
  /// not to call [onClosed] again.
  bool _closedByCode = false;
  bool get closedByCode => _closedByCode;

  // ─── Private helpers ──────────────────────────────────────────────────────

  void _setState(PaymentState next) {
    _state = next;
    notifyListeners();
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Entry point called by the Pay button.
  /// Takes [context] so it can open the Paystack popup and later pop the
  /// sheet. We capture [NavigatorState] immediately so it stays valid
  /// across await gaps.
  Future<void> initiatePayment(BuildContext context) async {
    final navigator = Navigator.of(context);
    _setState(const PaymentOpening());

    try {
      await FlutterPaystackPlus.openPaystackPopup(
        context: context,
        publicKey: config.publicKey,
        authorizationUrl: config.authorizationUrl,
        secretKey: config.secretKey,
        customerEmail: config.email,
        reference: config.reference,
        amount: config.amountInSubunit.toString(),
        currency: config.currency,

        onClosed: () {
          // User dismissed the Paystack webview without paying.
          _closedByCode = true;
          _setState(const PaymentIdle());
          navigator.pop();
          onClosed?.call();
        },

        onSuccess: () async {
          await _handleVerification(config.reference, navigator);
        },
      );
    } catch (e) {
      _setState(PaymentError('Failed to open payment: $e'));
    }
  }

  Future<void> _handleVerification(
      String reference,
      NavigatorState navigator,
      ) async {
    // No verification step — go straight to success.
    if (onVerify == null) {
      _closedByCode = true;
      _setState(PaymentSuccess(reference));
      navigator.pop();
      onSuccess?.call(reference);
      return;
    }

    _setState(const PaymentVerifying());

    try {
      await onVerify!(reference);

      _closedByCode = true;
      _setState(PaymentSuccess(reference));
      navigator.pop();
      onSuccess?.call(reference);
    } catch (e) {
      // Keep the sheet open so the user isn't left in the dark.
      _setState(PaymentError('Verification failed: $e'));
    }
  }

  /// Called by [PopScope.onPopInvokedWithResult] when the user physically swipes
  /// the sheet down. Fires [onClosed] only when WE didn't initiate the pop.
  void handleUserDismiss() {
    if (!_closedByCode) {
      onClosed?.call();
    }
  }

  /// Clears an error state back to idle after the UI has shown the SnackBar.
  void clearError() {
    if (_state is PaymentError) {
      _setState(const PaymentIdle());
    }
  }
}