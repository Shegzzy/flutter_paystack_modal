library;

export 'src/paystack_bottom_sheet.dart';
export 'src/models/paystack_config.dart';
export 'src/models/payment_state.dart';
export 'src/widgets/payment_summary_card.dart';

import 'package:flutter/material.dart';
import 'src/paystack_bottom_sheet.dart';
import 'src/models/paystack_config.dart';

/// Shows the Paystack payment bottom sheet.
///
/// ─── authUrl mode (production) ────────────────────────────────────────────
///
/// 1. Your backend calls POST /transaction/initialize and returns
///    authorization_url, reference, and your callback_url.
///
/// 2. Pass callbackUrl — this is the URL your Paystack dashboard is
///    configured to redirect to after payment. The WebView detects when
///    Paystack navigates to this URL and fires onSuccess.
///    Without it, the package can't know when payment is done.
///
/// ```dart
/// final config = PaystackConfig.withAuthUrl(
///   publicKey: 'pk_live_...',
///   authorizationUrl: result.authorizationUrl,
///   email: 'user@example.com',
///   amountInSubunit: 150000,
///   reference: result.reference,
///   callbackUrl: 'https://yourapp.com/payment/callback', // ← required
/// );
///
/// await showPaystackPayment(
///   context: context,
///   config: config,
///   onVerify: (ref) async => await myApi.verifyPayment(ref),
///   onSuccess: (ref) => Navigator.pushNamed(context, '/success'),
///   onClosed: () => print('cancelled'),
///   onError: (e) => print('error: $e'),
/// );
/// ```
///
/// ─── inline mode (testing) ────────────────────────────────────────────────
///
/// ```dart
/// final config = PaystackConfig.inline(
///   publicKey: 'pk_test_...',
///   email: 'test@example.com',
///   amountInSubunit: 150000,
///   reference: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
/// );
/// ```
Future<void> showPaystackPayment({
  required BuildContext context,
  required PaystackConfig config,
  String? title,
  String? description,
  void Function()? onClosed,
  Future<void> Function(String reference)? onVerify,
  void Function(String reference)? onSuccess,
  void Function(String error)? onError,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => PaystackBottomSheet(
      config: config,
      title: title,
      description: description,
      onClosed: onClosed,
      onVerify: onVerify,
      onSuccess: onSuccess,
      onError: onError,
    ),
  );
}
