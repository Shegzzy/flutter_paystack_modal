// lib/src/paystack_config.dart

/// Defines how Paystack payment is initialized.
enum PaystackMode {
  /// Uses a secretKey directly in the app.
  /// ⚠️ Only for development/testing. Never ship secret keys in production.
  directKeys,

  /// Uses a pre-fetched authorization URL from your backend/cloud function.
  /// ✅ Recommended for production — secret key stays on your server.
  cloudFunction,
}

class PaystackConfig {
  /// Your Paystack public key (pk_live_... or pk_test_...)
  final String publicKey;

  /// Secret key — only used in [PaystackMode.directKeys].
  /// ⚠️ Never include this in production apps.
  final String? secretKey;

  /// Authorization URL returned by your backend cloud function.
  /// Required when using [PaystackMode.cloudFunction].
  final String? authorizationUrl;

  /// Customer's email address
  final String email;

  /// Amount in the SMALLEST currency unit (kobo for NGN, cents for USD, etc.)
  /// e.g. NGN 1,500 → pass 150000
  final int amountInSubunit;

  /// Unique transaction reference — must match what your backend used to initialize
  final String reference;

  /// Currency code. Defaults to 'NGN'
  final String currency;

  /// Which initialization mode is active
  final PaystackMode mode;

  // ─── Named constructor: Direct Keys (dev/testing only) ──────────────────────

  const PaystackConfig.withKeys({
    required this.publicKey,
    required this.secretKey,
    required this.email,
    required this.amountInSubunit,
    required this.reference,
    this.currency = 'NGN',
  })  : authorizationUrl = null,
        mode = PaystackMode.directKeys;

  // ─── Named constructor: Cloud Function (recommended for production) ──────────

  const PaystackConfig.withAuthUrl({
    required this.publicKey,
    required this.authorizationUrl,
    required this.email,
    required this.amountInSubunit,
    required this.reference,
    this.currency = 'NGN',
  })  : secretKey = null,
        mode = PaystackMode.cloudFunction;

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Human-readable formatted amount, e.g. "NGN 1,500.00"
  String get formattedAmount {
    final amount = amountInSubunit / 100;
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  bool get isCloudFunctionMode => mode == PaystackMode.cloudFunction;
}
