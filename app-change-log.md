
### 2026-03-21 03:45:00 UTC
**Change summary:** Fixed critical MWA flow — app now returns to Godot immediately after wallet connect succeeds **or** is cancelled. Added graceful cancellation handling and UI busy state.

**Root cause fixed:** When the user dismisses the wallet prompt (back press), Android destroys `ComposeWalletActivity`; the `LaunchedEffect` coroutine is killed, leaving `myResult = null` forever. GDScript polled for 60 seconds before timing out with a generic error.

**Kotlin changes (`android/plugin/src/...walletadapterandroid/`):**
- `MyComposable.kt` — Added `myUserCancelled: Boolean` global flag; reset to `false` at the start of every composable operation.
- `MyComponentActivity.kt` — Overrode `onDestroy()`: sets `myUserCancelled = true` when activity is destroyed before `myResult` is set (user dismissed the wallet).
- `GDExtensionAndroidPlugin.kt` — `getConnectionStatus()` now returns `3` (cancelled) when `myUserCancelled` is true. `clearState()` also resets `myUserCancelled` and `myResult`.

**GDScript changes (`mobile_wallet_adapter.gd` — both SDK and example app copies):**
- All 4 polling loops now handle `status == 3` as an immediate clean exit instead of waiting 60 seconds.
- Fixed double-emit bug: one-shot signal listeners are disconnected *before* manually resolving on status 1/2.
- `authorize()` and `deauthorize()` call `clearState()` before starting to flush stale state from previous cancelled operations.
- `authorization_failed` emits `"user_cancelled"` on cancel, distinguishing it from network/auth errors.

**Example app changes (`main_scene.gd`):**
- Added `_set_busy(busy: bool)` helper that disables/enables all action buttons and shows "Waiting for wallet..." while an operation is in progress.
- All button handlers call `_set_busy(true)` / `_set_busy(false)` around `await` calls.
- Cancel events produce clear log messages (e.g., `"Connect cancelled by user."`).

**Files modified:**
- `android/plugin/src/main/java/plugin/walletadapterandroid/MyComposable.kt`
- `android/plugin/src/main/java/plugin/walletadapterandroid/MyComponentActivity.kt`
- `android/plugin/src/main/java/plugin/walletadapterandroid/GDExtensionAndroidPlugin.kt`
- `godot-solana-sdk/addons/SolanaSDK/Optional/SolanaService/Scripts/WalletAdapter/mobile_wallet_adapter.gd`
- `mwa-example-app/addons/SolanaSDK/Optional/SolanaService/Scripts/WalletAdapter/mobile_wallet_adapter.gd`
- `mwa-example-app/main_scene.gd`

**Why / alignment:**
- RFP deliverable: "Ensure users can easily disconnect, deauthorize, and reconnect" — a stuck UI requiring a 60-second timeout directly violates this.

**Verification:**
- Tap Connect → dismiss wallet → app returns in ~1s with "user_cancelled" in log, all buttons re-enabled.
- Tap Connect → approve → shows Connected status with address.
- Tap Reconnect after cancel → fresh authorize works correctly.

---

### 2026-03-20 23:15:00 UTC
**Change summary:** Resolved 4 critical GDScript compiler errors in `mobile_wallet_adapter.gd` that prevented the app from functioning on Android.
- Removed `@export` from `auth_cache` as custom `RefCounted` classes cannot be exported in Godot 4 unless they are `Resource` types.
- Added missing `await` to `authorize` call inside `reconnect()`.
- Fixed static-to-instance call for `get_message_signature()`.
- Fixed type inference error for `token` variable.

**Files modified:**
- `mwa-example-app/addons/SolanaSDK/Optional/SolanaService/Scripts/WalletAdapter/mobile_wallet_adapter.gd`

**Why / alignment:**
- RFP / deliverable: SDK improvements / Functional Example App.
- Ensures the MWA buttons actually trigger logic instead of hitting script errors.

**Verification:**
- User-reported errors matched script logic; local fixes apply standard GDScript 4.x best practices.
