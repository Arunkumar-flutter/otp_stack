## 0.0.3

Stable release with an app-controlled status API and the fan/stack animation.

- `OtpStackField`: animated OTP input that fans out while verifying and stacks
  into a single success card.
- App-controlled `OtpStackStatus` (`idle`, `verifying`, `success`, `error`);
  no state-management package required.
- `OtpStackController` for driving status and value with a `ChangeNotifier`.
- Each box holds exactly one digit; typing over a filled box replaces it.
- Paste a full code into any box to fill every field.
- A wrong code resets the boxes to empty after the error animation.
- Configurable length (4, 6, or any number of digits).
- SMS/email one-time-code autofill, `enabled` / `readOnly`, custom
  `inputFormatters`, `errorText`, and an accessibility label.
- `onRestored` fires after the error animation so the app can reset its status.

## 0.0.2

- Initial release of `otp_stack`.
- Added the reusable Flutter OTP input widget.
- Added OTP input animations and verification states.
- Designed for integration with custom authentication APIs.
