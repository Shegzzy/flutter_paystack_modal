// lib/src/widgets/payment_summary_card.dart

import 'package:flutter/material.dart';
import '../models/paystack_config.dart';

/// Displays the payment summary (email, reference, amount).
/// Purely presentational — no provider access, no business logic.
class PaymentSummaryCard extends StatelessWidget {
  final PaystackConfig config;

  const PaymentSummaryCard({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Email', value: config.email),
          const Divider(height: 20),
          _DetailRow(
            label: 'Reference',
            value: config.reference,
            valueMaxLines: 1,
          ),
          const Divider(height: 20),
          _DetailRow(
            label: 'Amount',
            value: config.formattedAmount,
            valueStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single label → value row. Private to this file — only used by
/// [PaymentSummaryCard].
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final int? valueMaxLines;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueStyle,
    this.valueMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: valueStyle ?? theme.textTheme.bodyMedium,
            textAlign: TextAlign.right,
            maxLines: valueMaxLines,
            overflow: valueMaxLines != null
                ? TextOverflow.ellipsis
                : TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}