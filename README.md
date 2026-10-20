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
- Paste a full code into any field and every box fills in.
- Four app-controlled states: `idle`, `verifying`, `success`, `error`.
- Fan-out animation on `verifying`, with a rotating gradient loading border.
- Stack animation with a checkmark on `success`.
- Automatic fan-back to editable cards on `error`.
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

The widget is controlled by the `status` you pass in. When the user finishes
typing, `onCompleted` fires and **you** start your request, then flip the
status when the response arrives.

```dart
class _VerifyScreenState extends State<VerifyScreen> {
  OtpStackStatus _status = OtpStackStatus.idle;

  Future<void> _onCompleted(String otp) async {
    setState(() => _status = OtpStackStatus.verifying);

    final valid = await verifyOtp(otp); // your API/repository call
    if (!mounted) return;

    setState(() {
      _status = valid
          ? OtpStackStatus.success
          : OtpStackStatus.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OtpStackField(
      length: 6,
      status: _status,
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
| `error`      | Flashes the error color, then fans back to editable cards.         |

`onStatusChanged` is emitted when the widget returns to `idle` on its own
(after the error animation), which is handy when the app mirrors the status.

### Using a controller

If you prefer to drive everything from a `ChangeNotifier` (no Provider needed),
attach an `OtpStackController`. It takes precedence over the `status` argument.

```dart
final _controller = OtpStackController();

OtpStackField(
  controller: _controller,
  onCompleted: (otp) async {
    _controller.setStatus(OtpStackStatus.verifying);
    final ok = await verifyOtp(otp);
    _controller.setStatus(ok ? OtpStackStatus.success : OtpStackStatus.error);
  },
);

// Elsewhere:
_controller.otp;          // current code
_controller.clear();      // clear the boxes
_controller.reset();      // clear + back to idle
```

## Customization

```dart
OtpStackField(
  length: 6,
  status: _status,
  cardWidth: 46,
  cardHeight: 58,
  cardGap: 4,
  height: 86,
  fanSpread: 15,
  primaryColor: Color(0xFF6675FF),
  successColor: Color(0xFF20A56B),
  errorColor: Color(0xFFE15A5A),
  textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
  cardTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  keyboardType: TextInputType.number,
  obscureText: false,
  autofocus: true,
  onChanged: (otp) {},
  onCompleted: (otp) {},
)
```

| Parameter       | Default                     | Description                                   |
| --------------- | --------------------------- | --------------------------------------------- |
| `length`        | `6`                         | Number of digits.                             |
| `status`        | `OtpStackStatus.idle`       | App-controlled state (ignored with controller).|
| `controller`    | `null`                      | Optional `OtpStackController`.                |
| `onChanged`     | `null`                      | Called with the full code on every change.    |
| `onCompleted`   | `null`                      | Called once each time the code is complete.   |
| `onStatusChanged` | `null`                    | Called when the widget returns to `idle`.     |
| `autofocus`     | `false`                     | Focus the first field on build/restore.       |
| `cardWidth`     | `46`                        | Card width in the fanned layout.              |
| `cardHeight`    | `58`                        | Card height.                                  |
| `cardGap`       | `4`                         | Gap between fanned cards.                     |
| `height`        | `86`                        | Total field height.                           |
| `fanSpread`     | `15`                        | How far outer cards spread from the center.   |
| `primaryColor`  | `0xFF6675FF`                | Focus / verifying color.                      |
| `successColor`  | `0xFF20A56B`                | Success color.                                |
| `errorColor`    | `0xFFE15A5A`                | Error color.                                  |

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
- Report issues on the
  [issue tracker](https://github.com/Arunkumar-flutter/otp_stack/issues).
