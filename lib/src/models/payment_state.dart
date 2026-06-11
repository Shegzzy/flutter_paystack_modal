// lib/src/models/payment_state.dart

/// All possible states the payment flow can be in.
/// Using a sealed class gives exhaustive pattern matching in the UI —
/// the compiler forces you to handle every case.
sealed class PaymentState {
  const PaymentState();
}

/// Nothing is happening — sheet is visible, WebView is loading.
class PaymentIdle extends PaymentState {
  const PaymentIdle();
}

/// The Paystack WebView is still loading its initial page.
class PaymentLoading extends PaymentState {
  const PaymentLoading();
}

/// WebView is fully loaded and the user can interact with the checkout.
class PaymentReady extends PaymentState {
  const PaymentReady();
}

/// Paystack redirected to the success callback URL — now we are
/// waiting for [onVerify] (your backend) to return.
class PaymentVerifying extends PaymentState {
  const PaymentVerifying();
}

/// Both Paystack and your backend confirmed success.
class PaymentSuccess extends PaymentState {
  final String reference;
  const PaymentSuccess(this.reference);
}

/// Something went wrong. [message] is shown in a SnackBar.
class PaymentError extends PaymentState {
  final String message;
  const PaymentError(this.message);
}

/// User closed the sheet without completing payment.
class PaymentCancelled extends PaymentState {
  const PaymentCancelled();
}
