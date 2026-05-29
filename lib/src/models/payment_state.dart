// lib/src/models/payment_state.dart

/// All possible states the payment flow can be in.
/// Using a sealed class gives exhaustive pattern matching in the UI —
/// the compiler forces you to handle every case.
sealed class PaymentState {
  const PaymentState();
}

/// Nothing is happening — sheet is visible, user hasn't tapped Pay yet.
class PaymentIdle extends PaymentState {
  const PaymentIdle();
}

/// The Paystack webview popup is launching.
class PaymentOpening extends PaymentState {
  const PaymentOpening();
}

/// Paystack confirmed the charge; we are now awaiting your backend
/// verification cloud function to return.
class PaymentVerifying extends PaymentState {
  const PaymentVerifying();
}

/// Both Paystack and your backend confirmed success.
class PaymentSuccess extends PaymentState {
  final String reference;
  const PaymentSuccess(this.reference);
}

/// Something went wrong. [message] is shown in a SnackBar.
/// The provider clears this back to [PaymentIdle] after the UI consumes it.
class PaymentError extends PaymentState {
  final String message;
  const PaymentError(this.message);
}