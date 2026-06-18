// lib/src/utils/url_classifier.dart

/// Pure-static URL classification helpers for Paystack redirect detection.
///
/// Extracted from [PaystackProvider] so the logic can be unit-tested
/// without a live WebView.
class UrlClassifier {
  UrlClassifier._();

  static const _knownSuccessPatterns = [
    'https://standard.paystack.co/close',
    'https://checkout.paystack.com/close',
    'paystack://close',
  ];

  static const _knownCancelPatterns = [
    'https://standard.paystack.co/cancel',
    'https://checkout.paystack.com/cancel',
  ];

  /// Returns true when [url] starts with [callbackUrl] (query-params stripped).
  /// Always false when [callbackUrl] is null or empty.
  static bool isCallbackUrl(String url, String? callbackUrl) {
    if (callbackUrl == null || callbackUrl.isEmpty) return false;
    final cbBase = callbackUrl.split('?').first.split('#').first;
    final urlBase = url.split('?').first.split('#').first;
    return urlBase.startsWith(cbBase);
  }

  /// Returns true when [url] matches one of Paystack's known success patterns.
  static bool isKnownSuccessUrl(String url) =>
      _knownSuccessPatterns.any((p) => url.startsWith(p));

  /// Returns true when [url] matches one of Paystack's known cancel patterns.
  static bool isKnownCancelUrl(String url) =>
      _knownCancelPatterns.any((p) => url.startsWith(p));

  /// Tries to pull `reference` or `trxref` from [url]'s query parameters.
  /// Returns null if neither is present or the URL cannot be parsed.
  static String? extractReference(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['reference'] ?? uri.queryParameters['trxref'];
    } catch (_) {
      return null;
    }
  }
}
