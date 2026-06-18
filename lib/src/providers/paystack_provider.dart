// lib/src/providers/paystack_provider.dart

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/paystack_config.dart';
import '../models/payment_state.dart';
import '../utils/url_classifier.dart';

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

  /// True once onPageFinished has fired at least once for this load.
  /// Used by [clearError] to decide whether to reload or just dismiss the overlay.
  bool _pageLoaded = false;

  /// Guards [fireSuccessCallback] against double-invocation during the
  /// pop-animation window.
  bool _successCallbackFired = false;

  Timer? _loadingTimer;

  /// Seconds before a stuck loading state is converted to a [PaymentError].
  static const _loadingTimeoutSeconds = 30;

  // ─── WebView ──────────────────────────────────────────────────────────────

  void _initWebViewController() {
    _startLoadingTimer();
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
            _loadingTimer?.cancel();
            _pageLoaded = true;
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
            if (UrlClassifier.isCallbackUrl(url, config.callbackUrl)) {
              log('[Paystack] callback URL errored (expected) — treating as success');
              _loadingTimer?.cancel();
              _handleSuccess(url);
              return;
            }

            // Ignore errors on known terminal pages (they 404 by design).
            if (UrlClassifier.isKnownSuccessUrl(url) ||
                UrlClassifier.isKnownCancelUrl(url)) return;

            // Ignore sub-resource errors (ads, analytics, fonts, etc.)
            if (error.isForMainFrame != null && !error.isForMainFrame!) return;

            // Real main-frame load failure
            if (_state is PaymentLoading || _state is PaymentReady) {
              _loadingTimer?.cancel();
              const msg = 'Failed to load payment page. Check your connection.';
              _setState(PaymentError(msg));
              onError?.call(msg);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(config.checkoutUrl));
  }

  void _startLoadingTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = Timer(
      const Duration(seconds: _loadingTimeoutSeconds),
      _onLoadTimeout,
    );
  }

  void _onLoadTimeout() {
    if (_state is PaymentLoading) {
      const msg = 'Payment page took too long to load. Check your connection.';
      _setState(PaymentError(msg));
      onError?.call(msg);
    }
  }

  // ─── Central URL check ────────────────────────────────────────────────────

  /// [preventable] = true when called from onNavigationRequest (can prevent).
  /// Returns true if this was a terminal URL.
  bool _checkUrl(String url, {required bool preventable}) {
    if (_handled) return true;

    // 1. Your app's callback URL — always means payment completed (success or
    //    needs verification). Paystack only redirects here after a charge attempt.
    if (UrlClassifier.isCallbackUrl(url, config.callbackUrl)) {
      _handleSuccess(url);
      return true;
    }

    // 2. Paystack's own close URL (inline mode / fallback)
    if (UrlClassifier.isKnownSuccessUrl(url)) {
      _handleSuccess(url);
      return true;
    }

    // 3. Explicit cancel URL
    if (UrlClassifier.isKnownCancelUrl(url)) {
      _handleCancel();
      return true;
    }

    return false;
  }

  // ─── Terminal handlers ────────────────────────────────────────────────────

  void _handleSuccess(String url) {
    if (_handled) return;
    _handled = true;
    _loadingTimer?.cancel();

    // Extract reference from the callback URL's query params if present,
    // otherwise fall back to the reference we already have.
    final ref = UrlClassifier.extractReference(url) ?? config.reference;
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
    _loadingTimer?.cancel();
    log('[Paystack] cancelled');
    _setState(const PaymentCancelled());
  }

  // ─── Called by the sheet ─────────────────────────────────────────────────

  /// Fires [onSuccess] exactly once. The sheet calls this from [_onStateChange]
  /// before popping, but the listener can fire more than once during the
  /// pop-animation window — [_successCallbackFired] prevents double-invocation.
  void fireSuccessCallback() {
    if (_successCallbackFired) return;
    _successCallbackFired = true;
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
    _pageLoaded = false;
    _setState(const PaymentLoading());
    _startLoadingTimer();
    _webViewController?.reload();
  }

  /// Called by the sheet after showing a [PaymentError] snackbar.
  ///
  /// If the page loaded successfully before the error (e.g. a verification
  /// failure), we just dismiss the error overlay — the WebView is still intact.
  /// If the page never loaded (e.g. a network timeout), we reload so the user
  /// isn't left with a blank WebView behind the dismissed overlay.
  void clearError() {
    if (_state is! PaymentError) return;
    if (_pageLoaded) {
      _setState(const PaymentReady());
    } else {
      retry();
    }
  }

  void _setState(PaymentState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }
}
