// lib/src/models/paystack_config.dart

/// Defines how the Paystack payment is initialized.
enum PaystackMode {
  /// Uses only a pre-fetched authorization URL from your backend.
  /// ✅ Recommended for production — secret key stays on your server.
  authUrl,

  /// Builds the checkout URL directly from email + amount + reference.
  /// ⚠️ For testing / simple integrations only. No secret key needed.
  inline,
}

class PaystackConfig {
  /// Your Paystack public key (pk_live_... or pk_test_...)
  final String publicKey;

  /// Authorization URL returned by your backend after calling
  /// POST https://api.paystack.co/transaction/initialize
  ///
  /// Required when using [PaystackMode.authUrl].
  final String? authorizationUrl;

  /// Customer's email address
  final String email;

  /// Amount in the SMALLEST currency unit (kobo for NGN, cents for USD, etc.)
  /// e.g. NGN 1,500 → pass 150000
  final int amountInSubunit;

  /// Unique transaction reference — must match what your backend used
  /// to initialize the transaction.
  final String reference;

  /// Currency code. Defaults to 'NGN'
  final String currency;

  /// Which initialization mode is active
  final PaystackMode mode;

  // ─── Named constructor: Auth URL (recommended for production) ─────────────

  /// Use this when your backend has already called
  /// POST https://api.paystack.co/transaction/initialize
  /// and returned the authorization_url and reference.
  const PaystackConfig.withAuthUrl({
    required this.publicKey,
    required this.authorizationUrl,
    required this.email,
    required this.amountInSubunit,
    required this.reference,
    this.currency = 'NGN',
  }) : mode = PaystackMode.authUrl;

  // ─── Named constructor: Inline (testing) ─────────────────────────────────

  /// Builds the Paystack inline checkout URL directly.
  /// ⚠️ Only for testing — no verification step, no secret key.
  const PaystackConfig.inline({
    required this.publicKey,
    required this.email,
    required this.amountInSubunit,
    required this.reference,
    this.currency = 'NGN',
  })  : authorizationUrl = null,
        mode = PaystackMode.inline;

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// The URL that will be loaded in the WebView.
  /// For [PaystackMode.authUrl], this is the authorization URL from your backend.
  /// For [PaystackMode.inline], this builds the standard Paystack JS checkout URL.
  String get checkoutUrl {
    if (mode == PaystackMode.authUrl) {
      return authorizationUrl!;
    }
    // Paystack inline checkout — opens the hosted payment page
    return 'https://checkout.paystack.com/$reference';
  }

  /// Human-readable formatted amount, e.g. "₦1,500.00"
  String get formattedAmount {
    final amount = amountInSubunit / 100;
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].split('').reversed.toList();
    final result = <String>[];
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && i % 3 == 0) result.add(',');
      result.add(intPart[i]);
    }
    final formatted = '${result.reversed.join()}.${parts[1]}';
    return switch (currency) {
      'NGN' => '₦$formatted',
      'USD' => '\$$formatted',
      'GHS' => 'GH₵$formatted',
      'ZAR' => 'R$formatted',
      'KES' => 'KSh$formatted',
      _ => '$currency $formatted',
    };
  }

  bool get isAuthUrlMode => mode == PaystackMode.authUrl;
}
