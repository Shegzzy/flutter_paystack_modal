// lib/src/providers/paystack_provider.dart

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/paystack_config.dart';
import '../models/payment_state.dart';

/// Owns every state transition in the payment flow.
///
/// How callbacks work reliably:
/// ─────────────────────────────────────────────────────────────────────────
/// Paystack always redirects to one of these callback URLs when the
/// transaction ends:
///
///   Success:   https://standard.paystack.co/close
///              https://checkout.paystack.com/close        (inline)
///
///   Cancelled: https://standard.paystack.co/close         (same URL — we
///              check the state to distinguish)
///
/// We intercept these via [WebViewController.setNavigationDelegate] and
/// call [onSuccess] / [onClosed] ourselves — no reliance on a third-party
/// package's callback mechanism.
class PaystackProvider extends ChangeNotifier {
  final PaystackConfig config;

  /// Called right after Paystack redirects to the success URL.
  /// Throw here to signal verification failure — the provider catches it
  /// and transitions to [PaymentError].
  final Future<void> Function(String reference)? onVerify;

  /// Called after [onVerify] completes (or immediately if no [onVerify]).
  final void Function(String reference)? onSuccess;

  /// Called when the user cancels / closes without paying.
  final void Function()? onClosed;

  /// Called when an error occurs during payment.
  final void Function(String error)? onError;

  PaystackProvider({
    required this.config,
    this.onVerify,
    this.onSuccess,
    this.onClosed,
    this.onError,
  }) {
    _initWebViewController();
  }

  // ─── State ────────────────────────────────────────────────────────────────

  PaymentState _state = const PaymentLoading();
  PaymentState get state => _state;

  WebViewController? _webViewController;
  WebViewController? get webViewController => _webViewController;

  bool get isLoading =>
      _state is PaymentLoading || _state is PaymentVerifying;

  bool get isReady => _state is PaymentReady;

  /// Prevents [onClosed] from firing when WE programmatically pop.
  bool _closedByCode = false;

  // ─── Paystack callback URL patterns ───────────────────────────────────────

  static const _successUrls = [
    'https://standard.paystack.co/close',
    'https://checkout.paystack.com/close',
    'paystack://close',
  ];

  static const _cancelUrls = [
    'https://standard.paystack.co/cancel',
    'https://checkout.paystack.com/cancel',
  ];

  // ─── WebView setup ────────────────────────────────────────────────────────

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (_state is PaymentLoading) return; // already in loading state
          },
          onPageFinished: (url) {
            if (_state is PaymentLoading) {
              _setState(const PaymentReady());
            }
          },
          onWebResourceError: (error) {
            // Ignore errors for the close/cancel redirect pages — they're
            // expected to return 404 or similar, we only care about the URL.
            final url = error.url ?? '';
            if (_isSuccessUrl(url) || _isCancelUrl(url)) return;

            log('WebView error: ${error.description} on ${error.url}');
            _setState(PaymentError(
              'Page failed to load: ${error.description}',
            ));
          },
          onNavigationRequest: (request) {
            final url = request.url;
            log('Paystack navigation: $url');

            if (_isSuccessUrl(url)) {
              _handleSuccess();
              return NavigationDecision.prevent;
            }

            if (_isCancelUrl(url)) {
              _handleCancel();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(config.checkoutUrl));
  }

  // ─── URL helpers ──────────────────────────────────────────────────────────

  bool _isSuccessUrl(String url) =>
      _successUrls.any((pattern) => url.startsWith(pattern));

  bool _isCancelUrl(String url) =>
      _cancelUrls.any((pattern) => url.startsWith(pattern));

  // ─── Event handlers ───────────────────────────────────────────────────────

  void _handleSuccess() {
    if (_state is PaymentSuccess || _state is PaymentVerifying) return;

    if (onVerify != null) {
      _runVerification();
    } else {
      _closedByCode = true;
      _setState(PaymentSuccess(config.reference));
      onSuccess?.call(config.reference);
    }
  }

  Future<void> _runVerification() async {
    _setState(const PaymentVerifying());
    try {
      await onVerify!(config.reference);
      _closedByCode = true;
      _setState(PaymentSuccess(config.reference));
      onSuccess?.call(config.reference);
    } catch (e) {
      log('Paystack verification failed: $e');
      final message = 'Verification failed: $e';
      _setState(PaymentError(message));
      onError?.call(message);
    }
  }

  void _handleCancel() {
    if (_state is PaymentSuccess) return; // already done
    _closedByCode = true;
    _setState(const PaymentCancelled());
    onClosed?.call();
  }

  // ─── Called by PopScope when user physically swipes down ─────────────────

  /// Called by [PopScope.onPopInvokedWithResult] when the user physically
  /// dismisses the sheet. Fires [onClosed] only when WE didn't initiate pop.
  void handleUserDismiss() {
    if (!_closedByCode && _state is! PaymentSuccess) {
      onClosed?.call();
    }
  }

  /// Retries loading the checkout URL — useful after a network error.
  void retry() {
    _setState(const PaymentLoading());
    _webViewController?.reload();
  }

  /// Clears an error state back to idle so the SnackBar isn't shown twice.
  void clearError() {
    if (_state is PaymentError) {
      _setState(const PaymentReady());
    }
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  void _setState(PaymentState next) {
    _state = next;
    notifyListeners();
  }
}
