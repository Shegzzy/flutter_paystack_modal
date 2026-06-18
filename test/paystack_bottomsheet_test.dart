import 'package:flutter_paystack_modal/paystack_bottomsheet.dart';
import 'package:flutter_paystack_modal/src/utils/amount_formatter.dart';
import 'package:flutter_paystack_modal/src/utils/url_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─── AmountFormatter ────────────────────────────────────────────────────────

  group('AmountFormatter', () {
    test('formats NGN correctly', () {
      expect(AmountFormatter.format(150000, 'NGN'), '₦1,500.00');
    });

    test('formats USD correctly', () {
      expect(AmountFormatter.format(100, 'USD'), '\$1.00');
    });

    test('formats GHS correctly', () {
      expect(AmountFormatter.format(50000, 'GHS'), 'GH₵500.00');
    });

    test('formats ZAR correctly', () {
      expect(AmountFormatter.format(20000, 'ZAR'), 'R200.00');
    });

    test('formats KES correctly', () {
      expect(AmountFormatter.format(75000, 'KES'), 'KSh750.00');
    });

    test('formats unknown currency with code prefix', () {
      expect(AmountFormatter.format(5000, 'EUR'), 'EUR 50.00');
    });

    test('inserts thousands separator for large amounts', () {
      expect(AmountFormatter.format(10000000, 'NGN'), '₦100,000.00');
    });

    test('formats sub-unit amounts smaller than 1', () {
      expect(AmountFormatter.format(50, 'NGN'), '₦0.50');
    });
  });

  // ─── UrlClassifier ──────────────────────────────────────────────────────────

  group('UrlClassifier.isKnownSuccessUrl', () {
    test('matches standard.paystack.co/close', () {
      expect(
        UrlClassifier.isKnownSuccessUrl('https://standard.paystack.co/close'),
        isTrue,
      );
    });

    test('matches checkout.paystack.com/close', () {
      expect(
        UrlClassifier.isKnownSuccessUrl('https://checkout.paystack.com/close'),
        isTrue,
      );
    });

    test('matches paystack://close scheme', () {
      expect(UrlClassifier.isKnownSuccessUrl('paystack://close'), isTrue);
    });

    test('does not match cancel URL', () {
      expect(
        UrlClassifier.isKnownSuccessUrl('https://standard.paystack.co/cancel'),
        isFalse,
      );
    });

    test('does not match arbitrary URL', () {
      expect(
        UrlClassifier.isKnownSuccessUrl('https://myapp.com/payment/callback'),
        isFalse,
      );
    });
  });

  group('UrlClassifier.isKnownCancelUrl', () {
    test('matches standard.paystack.co/cancel', () {
      expect(
        UrlClassifier.isKnownCancelUrl('https://standard.paystack.co/cancel'),
        isTrue,
      );
    });

    test('matches checkout.paystack.com/cancel', () {
      expect(
        UrlClassifier.isKnownCancelUrl('https://checkout.paystack.com/cancel'),
        isTrue,
      );
    });

    test('does not match close URL', () {
      expect(
        UrlClassifier.isKnownCancelUrl('https://standard.paystack.co/close'),
        isFalse,
      );
    });
  });

  group('UrlClassifier.isCallbackUrl', () {
    const callbackUrl = 'https://myapp.com/payment/callback';

    test('matches exact callback URL', () {
      expect(UrlClassifier.isCallbackUrl(callbackUrl, callbackUrl), isTrue);
    });

    test('matches callback URL with query params appended by Paystack', () {
      expect(
        UrlClassifier.isCallbackUrl(
          'https://myapp.com/payment/callback?trxref=TXN_123&reference=TXN_123',
          callbackUrl,
        ),
        isTrue,
      );
    });

    test('does not match a different path', () {
      expect(
        UrlClassifier.isCallbackUrl('https://myapp.com/other', callbackUrl),
        isFalse,
      );
    });

    test('returns false when callbackUrl is null', () {
      expect(
        UrlClassifier.isCallbackUrl(callbackUrl, null),
        isFalse,
      );
    });

    test('returns false when callbackUrl is empty string', () {
      expect(
        UrlClassifier.isCallbackUrl(callbackUrl, ''),
        isFalse,
      );
    });
  });

  group('UrlClassifier.extractReference', () {
    test('extracts reference query param', () {
      expect(
        UrlClassifier.extractReference(
          'https://myapp.com/callback?reference=TXN_123&trxref=TXN_123',
        ),
        'TXN_123',
      );
    });

    test('falls back to trxref when reference is absent', () {
      expect(
        UrlClassifier.extractReference(
          'https://myapp.com/callback?trxref=TXN_456',
        ),
        'TXN_456',
      );
    });

    test('returns null when neither param is present', () {
      expect(
        UrlClassifier.extractReference('https://myapp.com/callback'),
        isNull,
      );
    });

    test('returns null for a malformed URL', () {
      expect(UrlClassifier.extractReference(':::bad-url'), isNull);
    });
  });

  // ─── PaystackConfig ─────────────────────────────────────────────────────────

  group('PaystackConfig', () {
    group('withAuthUrl', () {
      const config = PaystackConfig.withAuthUrl(
        publicKey: 'pk_test_xxx',
        authorizationUrl: 'https://checkout.paystack.com/abc123',
        email: 'test@example.com',
        amountInSubunit: 150000,
        reference: 'TXN_001',
        callbackUrl: 'https://myapp.com/payment/callback',
      );

      test('checkoutUrl returns the authorizationUrl', () {
        expect(config.checkoutUrl, 'https://checkout.paystack.com/abc123');
      });

      test('isAuthUrlMode is true', () {
        expect(config.isAuthUrlMode, isTrue);
      });

      test('formattedAmount delegates to AmountFormatter', () {
        expect(config.formattedAmount, '₦1,500.00');
      });
    });

    group('inline', () {
      const config = PaystackConfig.inline(
        publicKey: 'pk_test_xxx',
        email: 'test@example.com',
        amountInSubunit: 150000,
        reference: 'TXN_001',
      );

      test('checkoutUrl builds URL from reference', () {
        expect(
          config.checkoutUrl,
          'https://checkout.paystack.com/TXN_001',
        );
      });

      test('isAuthUrlMode is false', () {
        expect(config.isAuthUrlMode, isFalse);
      });

      test('callbackUrl defaults to null', () {
        expect(config.callbackUrl, isNull);
      });

      test('currency defaults to NGN', () {
        expect(config.currency, 'NGN');
      });
    });
  });
}
