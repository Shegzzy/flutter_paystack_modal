// lib/flutter_paystack_modal.dart

library;

export 'package:flutter_paystack_modal/src/paystack_bottom_sheet.dart';
export 'package:flutter_paystack_modal/src/models/paystack_config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_paystack_modal/src/paystack_bottom_sheet.dart';
import 'package:flutter_paystack_modal/src/models/paystack_config.dart';


/// Shows a Paystack payment bottom sheet modal.
///
/// Works in two modes — choose the right one for your environment:
///
/// ─────────────────────────────────────────────────────────────────────────────
/// MODE 1 — Cloud Function (✅ Recommended for production)
/// Your backend initializes the payment and returns an authorization URL.
/// The secret key never touches the client app.
///
/// ```dart
/// // 1. Call your cloud function to initialize payment
/// final result = await FirebaseFunctions.instance
///   .httpsCallable('initializePayment')
///   .call({'email': email, 'amount': 150000});
///
/// final config = PaystackConfig.withAuthUrl(
///   publicKey: 'pk_live_...',
///   authorizationUrl: result.data['authorization_url'],
///   email: email,
///   amountInSubunit: 150000,
///   reference: result.data['reference'],
/// );
///
/// // 2. Show the bottom sheet
/// await showPaystackPayment(
///   context: context,
///   config: config,
///   onVerify: (ref) async {
///     // 3. Verify via your cloud function
///     await FirebaseFunctions.instance
///       .httpsCallable('verifyPayment')
///       .call({'reference': ref});
///   },
///   onSuccess: (ref) => print('All done! $ref'),
/// );
/// ```
///
/// ─────────────────────────────────────────────────────────────────────────────
/// MODE 2 — Direct Keys (⚠️ Dev/testing only)
///
/// ```dart
/// final config = PaystackConfig.withKeys(
///   publicKey: 'pk_test_...',
///   secretKey: 'sk_test_...',
///   email: 'user@example.com',
///   amountInSubunit: 150000,
///   reference: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
/// );
///
/// await showPaystackPayment(context: context, config: config);
/// ```
Future<void> showPaystackPayment({
  required BuildContext context,
  required PaystackConfig config,

  /// Optional label shown at the top of the bottom sheet
  String? title,

  /// Optional subtitle / description
  String? description,

  /// Called when the user closes without paying
  VoidCallback? onClosed,

  /// Called right after Paystack confirms the payment.
  /// Use this to call your backend verification cloud function.
  /// If this async call throws, an error snackbar is shown and
  /// the sheet stays open so the user isn't left in an unknown state.
  Future<void> Function(String reference)? onVerify,

  /// Called after [onVerify] completes (or immediately after Paystack
  /// confirms if [onVerify] is not provided).
  void Function(String reference)? onSuccess,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    builder: (_) => PaystackBottomSheet(
      config: config,
      title: title,
      description: description,
      onClosed: onClosed,
      onVerify: onVerify,
      onSuccess: onSuccess,
    ),
  );
}
