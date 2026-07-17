## 1.0.1

* Documentation improvements and naming cleanup.

## 1.0.0

* Initial release.
* Paystack checkout inside a bottom-sheet modal, built on `webview_flutter`.
* Navigation-layer redirect interception for reliable `onSuccess` / `onClosed` / `onError` callbacks.
* `onVerify` hook for server-side transaction verification before `onSuccess` fires.
* Two modes: `PaystackConfig.withAuthUrl` (backend-initialized, production) and `PaystackConfig.inline` (testing).
* Sealed `PaymentState` model for exhaustive UI state handling.
