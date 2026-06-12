// lib/src/providers/paystack_provider.dart

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/paystack_config.dart';
import '../models/payment_state.dart';

/// ── How Paystack's redirect actually works (authUrl mode) ────────────────────
///
/// When you initialize via your backend, Paystack sends the user to
/// checkout.paystack.com. After payment, it does NOT go to
/// standard.paystack.co/close — instead it redirects to whatever
/// callback_url you set in your Paystack dashboard (or passed during
/// transaction initialization), e.g.:
///
///   https://yourapp.com/payment/callback?trxref=xxx&reference=xxx
///
/// That URL may return a 404 in a WebView — that's fine, we only care that
/// the navigation happened. We detect it via [config.callbackUrl].
///
/// For cancellation, Paystack navigates back through checkout.paystack.com
/// and eventually hits /close or the user's close button — we detect that
/// by watching for the checkout origin to disappear or an explicit close URL.
///
/// ── Why onNavigationRequest isn't enough on Android ─────────────────────────
///
/// Android's WebView only fires onNavigationRequest for the MAIN frame.
/// Sub-frames (iframes) bypass it silently. We must also check onPageStarted,
/// which fires for all frames. Both feed into the same _checkUrl() so we
/// can't double-fire.
class PaystackProvider extends ChangeNotifier {
  final PaystackConfig config;
  final Future<void> Function(String reference)? onVerify;
  final void Function(String reference)? onSuccess;
  final void Function()? onClosed;
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

  bool get isLoading => _state is PaymentLoading || _state is PaymentVerifying;

  bool _handled = false;

  // ─── Known terminal URL patterns ─────────────────────────────────────────
  //
  // These cover the fallback case where no callbackUrl is configured,
  // or for inline mode.

  static const _knownSuccessPatterns = [
    'https://standard.paystack.co/close',
    'https://checkout.paystack.com/close',
    'paystack://close',
  ];

  static const _knownCancelPatterns = [
    'https://standard.paystack.co/cancel',
    'https://checkout.paystack.com/cancel',
  ];

  // ─── WebView ──────────────────────────────────────────────────────────────

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Fires for ALL frames on Android — primary intercept point.
          onPageStarted: (url) {
            log('[Paystack] pageStarted: $url');
            _checkUrl(url, preventable: false);
          },

          onPageFinished: (url) {
            log('[Paystack] pageFinished: $url');
            if (_state is PaymentLoading) {
              _setState(const PaymentReady());
            }
          },

          // Fires for main-frame navigations only — secondary intercept point.
          onNavigationRequest: (request) {
            log('[Paystack] navigationRequest: ${request.url}');
            final isTerminal = _checkUrl(request.url, preventable: true);
            return isTerminal
                ? NavigationDecision.prevent
                : NavigationDecision.navigate;
          },

          onWebResourceError: (error) {
            final url = error.url ?? '';
            log('[Paystack] resourceError: ${error.description} | url: $url | mainFrame: ${error.isForMainFrame}');

            // A 404/error on the callback URL means payment went through —
            // the app's server just isn't serving that route in the WebView.
            // Treat it as success.
            if (_isCallbackUrl(url)) {
              log('[Paystack] callback URL errored (expected) — treating as success');
              _handleSuccess(url);
              return;
            }

            // Ignore errors on known terminal pages (they 404 by design).
            if (_isKnownSuccessUrl(url) || _isKnownCancelUrl(url)) return;

            // Ignore sub-resource errors (ads, analytics, fonts, etc.)
            if (error.isForMainFrame != null && !error.isForMainFrame!) return;

            // Real main-frame load failure
            if (_state is PaymentLoading || _state is PaymentReady) {
              final msg = 'Failed to load payment page. Check your connection.';
              _setState(PaymentError(msg));
              onError?.call(msg);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(config.checkoutUrl));
  }

  // ─── URL classification ───────────────────────────────────────────────────

  bool _isCallbackUrl(String url) {
    final cb = config.callbackUrl;
    if (cb == null || cb.isEmpty) return false;
    // Strip query params from both for prefix matching
    final cbBase = cb.split('?').first.split('#').first;
    final urlBase = url.split('?').first.split('#').first;
    return urlBase.startsWith(cbBase);
  }

  bool _isKnownSuccessUrl(String url) =>
      _knownSuccessPatterns.any((p) => url.startsWith(p));

  bool _isKnownCancelUrl(String url) =>
      _knownCancelPatterns.any((p) => url.startsWith(p));

  // ─── Central URL check ────────────────────────────────────────────────────

  /// [preventable] = true when called from onNavigationRequest (can prevent).
  /// Returns true if this was a terminal URL.
  bool _checkUrl(String url, {required bool preventable}) {
    if (_handled) return true;

    // 1. Your app's callback URL — always means payment completed (success or
    //    needs verification). Paystack only redirects here after a charge attempt.
    if (_isCallbackUrl(url)) {
      _handleSuccess(url);
      return true;
    }

    // 2. Paystack's own close URL (inline mode / fallback)
    if (_isKnownSuccessUrl(url)) {
      _handleSuccess(url);
      return true;
    }

    // 3. Explicit cancel URL
    if (_isKnownCancelUrl(url)) {
      _handleCancel();
      return true;
    }

    return false;
  }

  // ─── Terminal handlers ────────────────────────────────────────────────────

  void _handleSuccess(String url) {
    if (_handled) return;
    _handled = true;

    // Extract reference from the callback URL's query params if present,
    // otherwise fall back to the reference we already have.
    final ref = _extractReference(url) ?? config.reference;
    log('[Paystack] success — reference: $ref');

    if (onVerify != null) {
      _runVerification(ref);
    } else {
      _setState(PaymentSuccess(ref));
    }
  }

  Future<void> _runVerification(String ref) async {
    _setState(const PaymentVerifying());
    try {
      await onVerify!(ref);
      _setState(PaymentSuccess(ref));
    } catch (e) {
      _handled = false; // allow retry
      log('[Paystack] verification failed: $e');
      const msg = 'Payment verification failed. Please contact support.';
      _setState(PaymentError(msg));
      onError?.call(msg);
    }
  }

  void _handleCancel() {
    if (_handled) return;
    _handled = true;
    log('[Paystack] cancelled');
    _setState(const PaymentCancelled());
  }

  /// Tries to pull `reference` or `trxref` from the URL query string.
  String? _extractReference(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['reference'] ??
          uri.queryParameters['trxref'];
    } catch (_) {
      return null;
    }
  }

  // ─── Called by the sheet ─────────────────────────────────────────────────

  /// Sheet calls this AFTER Navigator.pop() so callbacks fire in a clean state.
  void fireSuccessCallback() {
    final ref = state is PaymentSuccess
        ? (state as PaymentSuccess).reference
        : config.reference;
    onSuccess?.call(ref);
  }

  void fireClosedCallback() => onClosed?.call();

  void handleUserDismiss() {
    if (!_handled && _state is! PaymentSuccess) {
      _handled = true;
      _setState(const PaymentCancelled());
    }
  }

  void retry() {
    _handled = false;
    _setState(const PaymentLoading());
    _webViewController?.reload();
  }

  void clearError() {
    if (_state is PaymentError) _setState(const PaymentReady());
  }

  void _setState(PaymentState next) {
    _state = next;
    notifyListeners();
  }
}
