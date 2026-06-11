# paystack_bottomsheet

A Flutter package that opens Paystack's checkout inside a bottom sheet using a fully-controlled `WebViewController`.

**Why this instead of flutter_paystack_plus?**  
Other packages rely on the Paystack JS SDK's own callback mechanism to fire `onSuccess` and `onClosed`. When the WebView closes before the JS has a chance to fire those events, the callbacks never arrive. This package intercepts Paystack's redirect URLs directly at the navigation layer, so callbacks are **always reliable**.

---

## Setup

### 1. Add the dependency

```yaml
dependencies:
  paystack_bottomsheet:
    path: ../paystack_bottomsheet  # or your pub.dev path once published
```

### 2. Android — enable cleartext traffic (if needed for test keys)

In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
android:usesCleartextTraffic="true"
```

### 3. iOS — allow arbitrary loads (test keys only)

In `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

---

## Usage

### Production (backend-initialized)

Your server calls `POST https://api.paystack.co/transaction/initialize`, then returns the `authorization_url` and `reference` to your app.

```dart
import 'package:paystack_bottomsheet/paystack_bottomsheet.dart';

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
);

// 3. Show the sheet
await showPaystackPayment(
  context: context,
  config: config,
  title: 'Subscribe to Pro',
  description: 'Monthly plan — cancel anytime',
  onVerify: (ref) async {
    // Called after Paystack confirms — verify on your backend
    await myApi.verifyPayment(ref);
  },
  onSuccess: (ref) {
    // Payment confirmed and verified
    Navigator.pushReplacementNamed(context, '/success');
  },
  onClosed: () {
    // User cancelled
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment cancelled')),
    );
  },
  onError: (err) {
    // Something went wrong
    print('Payment error: $err');
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
  onSuccess: (ref) => print('Success: $ref'),
  onClosed: () => print('Cancelled'),
);
```

---

## How callbacks work

Paystack always redirects to one of these URLs when a transaction ends:

| Event      | URL |
|------------|-----|
| Success    | `https://standard.paystack.co/close` |
| Cancelled  | `https://standard.paystack.co/cancel` |

The `WebViewController`'s `NavigationDelegate` intercepts these in `onNavigationRequest` and fires the appropriate callback **before** the navigation happens — so they always fire even if the page doesn't fully load.

---

## API

### `showPaystackPayment`

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `BuildContext` | Required |
| `config` | `PaystackConfig` | Required — see constructors below |
| `title` | `String?` | Sheet header title |
| `description` | `String?` | Sheet subtitle |
| `onVerify` | `Future<void> Function(String ref)?` | Called after success redirect. Throw to signal failure. |
| `onSuccess` | `void Function(String ref)?` | Called after `onVerify` completes |
| `onClosed` | `void Function()?` | Called when user cancels |
| `onError` | `void Function(String error)?` | Called on any error |

### `PaystackConfig.withAuthUrl`

```dart
PaystackConfig.withAuthUrl({
  required String publicKey,
  required String authorizationUrl,  // from your backend
  required String email,
  required int amountInSubunit,
  required String reference,
  String currency = 'NGN',
})
```

### `PaystackConfig.inline`

```dart
PaystackConfig.inline({
  required String publicKey,
  required String email,
  required int amountInSubunit,
  required String reference,
  String currency = 'NGN',
})
```
