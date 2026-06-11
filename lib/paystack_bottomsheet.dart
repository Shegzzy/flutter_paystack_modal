// lib/paystack_bottomsheet.dart
library;

export 'src/paystack_bottom_sheet.dart';
export 'src/models/paystack_config.dart';
export 'src/models/payment_state.dart';

import 'package:flutter/material.dart';
import 'src/paystack_bottom_sheet.dart';
import 'src/models/paystack_config.dart';

/// Shows a Paystack payment bottom sheet.
///
/// The payment flow uses a fully-controlled [WebViewController] that intercepts
/// Paystack's redirect URLs directly — so [onSuccess] and [onClosed] fire
/// reliably every time, regardless of how the WebView closes.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// MODE 1 — Backend-initialized (✅ Recommended for production)
/// Your server calls POST /transaction/initialize and returns the
/// authorization_url and reference. The secret key never touches the app.
///
/// ```dart
/// // 1. Call your backend to initialize the transaction
/// final result = await myApi.initializePayment(
///   email: email,
///   amountInKobo: 150000,
/// );
///
/// // 2. Build the config from the backend response
/// final config = PaystackConfig.withAuthUrl(
///   publicKey: 'pk_live_...',
///   authorizationUrl: result.authorizationUrl,
///   email: email,
///   amountInSubunit: 150000,
///   reference: result.reference,
/// );
///
/// // 3. Show the sheet
/// await showPaystackPayment(
///   context: context,
///   config: config,
///   onVerify: (ref) async {
///     // 4. Verify via your backend
///     await myApi.verifyPayment(ref);
///   },
///   onSuccess: (ref) {
///     print('Payment confirmed! $ref');
///   },
///   onClosed: () {
///     print('User cancelled');
///   },
///   onError: (err) {
///     print('Error: $err');
///   },
/// );
/// ```
///
/// ─────────────────────────────────────────────────────────────────────────────
/// MODE 2 — Inline (⚠️ Testing only)
///
/// ```dart
/// final config = PaystackConfig.inline(
///   publicKey: 'pk_test_...',
///   email: 'user@example.com',
///   amountInSubunit: 150000,
///   reference: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
/// );
///
/// await showPaystackPayment(
///   context: context,
///   config: config,
///   onSuccess: (ref) => print('Done: $ref'),
/// );
/// ```
Future<void> showPaystackPayment({
  required BuildContext context,
  required PaystackConfig config,

  /// Optional label shown at the top of the bottom sheet.
  String? title,

  /// Optional subtitle / description.
  String? description,

  /// Called when the user closes the sheet without paying.
  void Function()? onClosed,

  /// Called right after Paystack confirms the payment (redirect intercepted).
  /// Use this to call your backend verification endpoint.
  /// Throw here to signal failure — the sheet will show an error + retry.
  Future<void> Function(String reference)? onVerify,

  /// Called after [onVerify] completes (or immediately if no [onVerify]).
  void Function(String reference)? onSuccess,

  /// Called on any error (network, verification failure, etc.).
  void Function(String error)? onError,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false, // We manage drag/dismiss via PopScope
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
