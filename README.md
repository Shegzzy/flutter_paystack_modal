# flutter_paystack_modal

A Flutter package that opens Paystack's checkout inside a bottom-sheet modal using a fully-controlled `WebViewController` — built from scratch on `webview_flutter`, with no dependency on `flutter_paystack_plus` or `paystack_payment`.

## Why this package?

Existing Paystack packages rely on the Paystack JS SDK's own callback mechanism to fire `onSuccess` and `onClosed`. If the WebView closes before the JS has a chance to fire those events, the callbacks never arrive — and your app never learns whether the user paid.

`flutter_paystack_modal` intercepts Paystack's redirect URLs directly at the navigation layer (`NavigationDelegate.onNavigationRequest`), **before** any page load happens. Callbacks fire reliably, every time — even if the checkout page never finishes loading.

**Other things it gets right:**

- **Verification is part of the flow.** The `onVerify` hook runs your backend verification *between* Paystack's redirect and `onSuccess`, so "success" in your app always means "verified on your server" — never just "the WebView said so."
- **Exhaustive payment states.** The flow is modelled as a sealed `PaymentState` class (`PaymentIdle`, `PaymentLoading`, `PaymentReady`, `PaymentVerifying`, `PaymentSuccess`, `PaymentError`) — the compiler forces you to handle every case.
- **Backend-first by design.** Production mode expects a server-initialized transaction (`authorization_url` + `reference`); your secret key never touches the client.

## Installation

```yaml
dependencies:
  flutter_paystack_modal: ^1.0.1
```

Or straight from GitHub while it's not yet on pub.dev:

```yaml
dependencies:
  flutter_paystack_modal:
    git:
      url: https://github.com/Shegzzy/flutter_paystack_modal
```

### Android — cleartext traffic (test keys only)

In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
android:usesCleartextTraffic="true"
```

### iOS — arbitrary loads (test keys only)

In `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

Neither is needed for live keys — remove both before release builds.

## Usage

### Production (backend-initialized)

Your server calls `POST https://api.paystack.co/transaction/initialize` and returns the `authorization_url` and `reference` to your app. Pass your dashboard's `callbackUrl` so the WebView knows which redirect means "payment done" — if omitted, the package falls back to watching Paystack's standard `standard.paystack.co/close` URLs.

```dart
import 'package:flutter_paystack_modal/paystack_bottomsheet.dart';

// 1. Initialize via your backend
final result = await myApi.initializePayment(
  email: 'user@example.com',
  amountInKobo: 150000, // NGN 1,500
);

// 2. Build config
final config = PaystackConfig.withAuthUrl(
  publicKey: 'pk_live_...',
  authorizationUrl: result.authorizationUrl,
  email: 'user@example.com',
  amountInSubunit: 150000,
  reference: result.reference,
  callbackUrl: 'https://yourapp.com/payment/callback',
);

// 3. Show the sheet
await showPaystackPayment(
  context: context,
  config: config,
  title: 'Subscribe to Pro',
  description: 'Monthly plan — cancel anytime',
  onVerify: (ref) async {
    // Runs after Paystack's redirect, before onSuccess.
    // Throw here to signal verification failure.
    await myApi.verifyPayment(ref);
  },
  onSuccess: (ref) {
    // Paystack redirected AND your backend verified.
    Navigator.pushReplacementNamed(context, '/success');
  },
  onClosed: () {
    // User cancelled.
  },
  onError: (err) {
    // Verification threw, or something else went wrong.
  },
);
```

### Testing (inline mode)

```dart
final config = PaystackConfig.inline(
  publicKey: 'pk_test_...',
  email: 'test@example.com',
  amountInSubunit: 150000,
  reference: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
);

await showPaystackPayment(
  context: context,
  config: config,
  onSuccess: (ref) => debugPrint('Success: $ref'),
  onClosed: () => debugPrint('Cancelled'),
);
```

## How callback interception works

Paystack always ends a transaction by redirecting the checkout WebView:

| Event     | URL                                                     |
| --------- | ------------------------------------------------------- |
| Success   | Your `callbackUrl`, or `https://standard.paystack.co/close` |
| Cancelled | `https://standard.paystack.co/cancel`                   |

The `NavigationDelegate` intercepts these in `onNavigationRequest` and fires the matching callback **before** the navigation happens — so callbacks fire even when the redirect target never loads.

## API reference

### `showPaystackPayment`

| Parameter     | Type                                   | Description                                             |
| ------------- | -------------------------------------- | ------------------------------------------------------- |
| `context`     | `BuildContext`                         | Required                                                |
| `config`      | `PaystackConfig`                       | Required — see constructors below                       |
| `title`       | `String?`                              | Sheet header title                                      |
| `description` | `String?`                              | Sheet subtitle                                          |
| `onVerify`    | `Future<void> Function(String ref)?`   | Runs after the success redirect. Throw to signal failure. |
| `onSuccess`   | `void Function(String ref)?`           | Runs after `onVerify` completes                         |
| `onClosed`    | `void Function()?`                     | Runs when the user cancels                              |
| `onError`     | `void Function(String error)?`         | Runs on any error                                       |

### `PaystackConfig.withAuthUrl` — production

```dart
PaystackConfig.withAuthUrl({
  required String publicKey,
  required String authorizationUrl, // from your backend
  required String email,
  required int amountInSubunit,
  required String reference,
  String? callbackUrl,              // your dashboard callback URL
  String currency = 'NGN',
})
```

### `PaystackConfig.inline` — testing

```dart
PaystackConfig.inline({
  required String publicKey,
  required String email,
  required int amountInSubunit,
  required String reference,
  String currency = 'NGN',
})
```

### `PaymentState`

A sealed class covering the whole flow — pattern-match it if you build custom UI on top of the sheet:

```dart
switch (state) {
  case PaymentIdle():       // sheet visible, nothing happening yet
  case PaymentLoading():    // checkout WebView loading
  case PaymentReady():      // user can interact with checkout
  case PaymentVerifying():  // redirect received, onVerify running
  case PaymentSuccess(:final reference):
  case PaymentError(:final message):
}
```

## License

MIT — see [LICENSE](LICENSE).
