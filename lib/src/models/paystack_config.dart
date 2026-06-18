// lib/src/models/paystack_config.dart

import '../utils/amount_formatter.dart';

enum PaystackMode { authUrl, inline }

class PaystackConfig {
  final String publicKey;
  final String? authorizationUrl;
  final String email;
  final int amountInSubunit;
  final String reference;
  final String currency;
  final PaystackMode mode;

  /// Your Paystack dashboard callback URL, e.g. https://yourapp.com/payment/callback
  /// Required for [PaystackMode.authUrl] so the WebView knows which URL
  /// means "payment done" and triggers onSuccess.
  /// If null, falls back to watching the standard paystack.co/close URLs.
  final String? callbackUrl;

  const PaystackConfig.withAuthUrl({
    required this.publicKey,
    required this.authorizationUrl,
    required this.email,
    required this.amountInSubunit,
    required this.reference,
    this.callbackUrl,
    this.currency = 'NGN',
  }) : mode = PaystackMode.authUrl;

  const PaystackConfig.inline({
    required this.publicKey,
    required this.email,
    required this.amountInSubunit,
    required this.reference,
    this.currency = 'NGN',
  })  : authorizationUrl = null,
        callbackUrl = null,
        mode = PaystackMode.inline;

  String get checkoutUrl {
    if (mode == PaystackMode.authUrl) return authorizationUrl!;
    return 'https://checkout.paystack.com/$reference';
  }

  /// Human-readable amount string, e.g. `₦1,500.00`.
  String get formattedAmount => AmountFormatter.format(amountInSubunit, currency);

  bool get isAuthUrlMode => mode == PaystackMode.authUrl;
}
