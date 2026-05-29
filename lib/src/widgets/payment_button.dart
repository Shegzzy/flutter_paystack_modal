// lib/src/widgets/pay_button.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment_state.dart';
import '../providers/paystack_provider.dart';

/// The Pay button. Reads [PaystackProvider] from context to:
/// - Show the right label or loading indicator based on current state
/// - Disable itself while [isLoading] is true
/// - Call [PaystackProvider.initiatePayment] on tap
///
/// No logic lives here — this widget only reflects state and fires events.
class PayButton extends StatelessWidget {
  const PayButton({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch rebuilds this widget whenever the provider notifies.
    final provider = context.watch<PaystackProvider>();
    final state = provider.state;

    final String loadingLabel = switch (state) {
      PaymentOpening() => 'Opening payment...',
      PaymentVerifying() => 'Verifying payment...',
      _ => '',
    };

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: provider.isLoading
            ? null
            : () => provider.initiatePayment(context),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: provider.isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              loadingLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        )
            : Text(
          'Pay ${provider.config.formattedAmount}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}