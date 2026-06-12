// lib/src/models/paystack_config.dart

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
