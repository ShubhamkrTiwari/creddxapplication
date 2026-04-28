# Implementation Plan - Fix Balance Persistence and Profile Screen Syntax

The user reported that balances from a previous account persist after logging in with a new ID. Additionally, there are syntax errors in `user_profile_screen.dart`.

## User Review Required

> [!NOTE]
> `AuthService.loginWithOtp` already seems to call `UnifiedWalletService.clearState()`. However, if the `UnifiedWalletService.initialize()` in `HomeScreen` or `WalletScreen` is triggered before the login process completes or if there's a race condition, it might be an issue.
> I will ensure that `clearState()` is also called whenever we are about to fetch new balances after a successful login to be absolutely sure.
> Also, I'll fix the syntax errors in `user_profile_screen.dart`.

## Proposed Changes

### UI & Syntax Fixes

#### [user_profile_screen.dart](file:///home/vaibhav/StudioProjects/creddx/lib/screens/user_profile_screen.dart)

- Fix the malformed `build` method and closing braces/parens.
- Remove unused imports.

### Authentication & State Management

#### [auth_service.dart](file:///home/vaibhav/StudioProjects/creddx/lib/services/auth_service.dart)

- Ensure `UnifiedWalletService.clearState()` is called effectively. (It already is, but I'll verify the flow).

#### [unified_wallet_service.dart](file:///home/vaibhav/StudioProjects/creddx/lib/services/unified_wallet_service.dart)

- Modify `initialize()` to be more resilient to account changes.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to verify syntax fixes.

### Manual Verification
- Verify that `user_profile_screen.dart` compiles.
- Mock a login scenario (mental check) to ensure `clearState()` is called.
