# otp_stack

Animated OTP input fields that **fan out** while a request is verifying and
**stack into a single card** when it succeeds. The package is only an input
widget: your app owns the verification status, so it works with any backend and
any state-management approach (or none at all).

<p>
  <img src="https://img.shields.io/badge/platform-flutter-blue.svg" alt="Flutter">
  <img src="https://img.shields.io/badge/sdk-%5E3.12.2-blue.svg" alt="Dart SDK">
</p>

## Features

- Editable OTP cards with automatic focus movement and backspace support.
- Each box holds exactly one digit; typing over a filled box replaces it.
- Paste a full code into any field and every box fills in.
- Configurable length — use 4, 6 (or any) digits.
- Four app-controlled states: `idle`, `verifying`, `success`, `error`.
- Fan-out animation on `verifying`, with a rotating gradient loading border.
- Stack animation with a checkmark on `success`.
- Wrong code resets the boxes to empty, with an `onRestored` hook.
- SMS / email one-time-code autofill out of the box.
- `enabled` / `readOnly`, custom `inputFormatters`, optional `errorText`, and
  an accessibility label.
- Optional `OtpStackController` for apps that prefer a `ChangeNotifier`.
- No Provider, Bloc, Riverpod or backend dependency.

## Getting started

```yaml
dependencies:
  otp_stack: ^1.0.0
```

```dart
import 'package:otp_stack/otp_stack.dart';
```

## Usage

The recommended way is to pass the `status` you already hold. When the user
finishes typing, `onCompleted` fires and **you** start your request, then flip
the status when the response arrives.

```dart
class _VerifyScreenState extends State<VerifyScreen> {
  OtpStackStatus _status = OtpStackStatus.idle;

  Future<void> _onCompleted(String otp) async {
    setState(() => _status = OtpStackStatus.verifying);

    final valid = await verifyOtp(otp); // your API/repository call
    if (!mounted) return;

    setState(() {
      _status = valid ? OtpStackStatus.success : OtpStackStatus.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OtpStackField(
      length: 6,
      status: _status,
      onRestored: (_) => setState(() => _status = OtpStackStatus.idle),
      onChanged: (otp) => debugPrint('otp: $otp'),
      onCompleted: _onCompleted,
    );
  }
}
```

### State machine

| Status       | What the package does                                              |
| ------------ | ------------------------------------------------------------------ |
| `idle`       | Shows the editable input cards.                                    |
| `verifying`  | Fans the cards out and animates the loading border.                |
| `success`    | Collapses the cards into one card with a checkmark.                |
| `error`      | Holds the fan briefly, then fans back and **clears the fields** so the user can retry. |

When `error` finishes restoring, `onRestored` fires with `OtpStackStatus.idle`
and the boxes are empty. Use it to reset your own status so the UI and the
field stay in sync.

### Pin length

`length` controls how many boxes are shown — 4, 6, or any value. The fan and
stack animations adapt to it automatically.

```dart
OtpStackField(length: 4, status: _status, onCompleted: _onCompleted);
```

### Using a controller

If you prefer to drive everything from a `ChangeNotifier` (no Provider needed),
attach an `OtpStackController`. It takes precedence over the `status` argument,
and the two must not be used together.

```dart
final _controller = OtpStackController();

OtpStackField(
  controller: _controller,
  onCompleted: (otp) async {
    _controller.setStatus(OtpStackStatus.verifying);
    final ok = await verifyOtp(otp);
    _controller.setStatus(ok ? OtpStackStatus.success : OtpStackStatus.error);
  },
  onRestored: (_) => _controller.setStatus(OtpStackStatus.idle),
);

// Elsewhere:
_controller.otp;          // current code
_controller.clear();      // clear the boxes (keeps the status)
_controller.reset();      // clear + back to idle
```

`OtpStackController` is a `ChangeNotifier`; call `dispose()` when you are done
with it.

## Customization

```dart
OtpStackField(
  length: 6,
  status: _status,
  enabled: true,
  readOnly: false,
  obscureText: false,
  keyboardType: TextInputType.number,
  inputFormatters: null,           // defaults to digits only
  autofillHints: const [AutofillHints.oneTimeCode],
  textInputAction: null,           // next, or done on the last field
  cursorColor: null,               // defaults to primaryColor
  semanticLabel: 'One-time code',
  errorText: _error,
  errorColor: Color(0xFFE15A5A),
  cardWidth: 46,
  cardHeight: 58,
  cardGap: 4,
  height: 86,
  fanSpread: 15,
  primaryColor: Color(0xFF6675FF),
  successColor: Color(0xFF20A56B),
  textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
  cardTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  autofocus: true,
  onChanged: (otp) {},
  onCompleted: (otp) {},
)
```

| Parameter         | Default                     | Description                                        |
| ----------------- | --------------------------- | -------------------------------------------------- |
| `length`          | `6`                         | Number of digits.                                  |
| `status`          | `null` (idle)               | App-controlled state. Mutually exclusive with `controller`. |
| `controller`      | `null`                      | Optional `OtpStackController`.                     |
| `onChanged`       | `null`                      | Called with the full code on every change.         |
| `onCompleted`     | `null`                      | Called once each time the code is complete.        |
| `onRestored`      | `null`                      | Called with `idle` after the error animation.      |
| `autofocus`       | `false`                     | Focus the first field on build/restore.            |
| `enabled`         | `true`                      | Whether the fields accept input.                   |
| `readOnly`        | `false`                     | Focusable but not editable.                        |
| `obscureText`     | `false`                     | Hide the entered digits.                           |
| `keyboardType`    | `TextInputType.number`      | Keyboard type.                                     |
| `inputFormatters` | digits only                 | Override to allow other characters.                |
| `autofillHints`   | `[AutofillHints.oneTimeCode]` | Triggers SMS/email autofill.                     |
| `textInputAction` | next / done                 | Override the keyboard action.                      |
| `cursorColor`     | `primaryColor`              | Cursor color.                                      |
| `semanticLabel`   | `null`                      | Accessibility label for the whole field.           |
| `errorText`       | `null`                      | Optional message shown under the field.            |
| `errorColor`      | `0xFFE15A5A`                | Color of `errorText`.                              |
| `cardWidth`       | `46`                        | Card width in the fanned layout.                   |
| `cardHeight`      | `58`                        | Card height.                                       |
| `cardGap`         | `4`                         | Gap between fanned cards (and input padding).      |
| `height`          | `86`                        | Total field height.                                |
| `fanSpread`       | `15`                        | How far outer cards spread from the center.        |
| `primaryColor`    | `0xFF6675FF`                | Focus / verifying color.                           |
| `successColor`    | `0xFF20A56B`                | Success check color.                               |
| `textStyle`       | `22 / w600`                 | Digit style while editing.                         |
| `cardTextStyle`   | `20 / w700`                 | Digit style on the fanned / stacked cards.         |

> The cards keep their light-blue border in every state; only the two center
> cards turn `primaryColor` while verifying. Error feedback is shown by the app
> (via `errorText` or your own status UI), not by recoloring the cards.

## Accessibility

The widget renders one `TextField` per digit, so set `semanticLabel` to present
the group as a single one-time code to screen readers. SMS autofill works out
of the box through `autofillHints`.

## Example

A complete, runnable demo lives in [`example/`](example/). It uses
`OtpStackController`, mimics an API with a one-second delay, and treats
`000000` as an invalid code so you can see the error animation.

```bash
cd example
flutter run
```

## Additional information

- The package deliberately owns no verification logic; only the animations and
  input handling.
- `OtpBorderPainter` and the field's state class are internal and are not
  exported from `package:otp_stack/otp_stack.dart`.
- Report issues on the
  [issue tracker](https://github.com/Arunkumar-flutter/otp_stack/issues).
