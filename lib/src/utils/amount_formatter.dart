// lib/src/utils/amount_formatter.dart

/// Formats a payment amount for display.
///
/// Extracted from [PaystackConfig] so presentation logic stays out of
/// the model layer and can be tested independently.
class AmountFormatter {
  AmountFormatter._();

  /// Converts [amountInSubunit] (e.g. kobo, cents) to a human-readable string
  /// with the appropriate currency symbol, e.g. `₦1,500.00`.
  static String format(int amountInSubunit, String currency) {
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
}
