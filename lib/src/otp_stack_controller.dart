import 'package:flutter/foundation.dart' show ChangeNotifier, internal;

import 'otp_stack_binding.dart';
import 'otp_stack_status.dart';

/// A [ChangeNotifier] that drives an `OtpStackField` without Provider or any
/// other state-management package.
///
/// ```dart
/// final controller = OtpStackController();
///
/// OtpStackField(
///   controller: controller,
///   onCompleted: (otp) async {
///     controller.setStatus(OtpStackStatus.verifying);
///     final ok = await verify(otp);
///     controller.setStatus(
///       ok ? OtpStackStatus.success : OtpStackStatus.error,
///     );
///   },
///   onRestored: (_) => controller.setStatus(OtpStackStatus.idle),
/// );
/// ```
///
/// When a controller is attached, it takes precedence over the `status`
/// argument of `OtpStackField`.
///
/// The controller is a [ChangeNotifier]; dispose it when you are done with it.
class OtpStackController extends ChangeNotifier {
  OtpStackFieldBinding? _field;
  OtpStackStatus _status = OtpStackStatus.idle;

  /// The current verification status.
  OtpStackStatus get status => _status;

  /// The current OTP string, or an empty string before a field is attached.
  String get otp => _field?.otp ?? '';

  /// The current digits, one entry per field.
  List<String> get digits => _field?.digits ?? const <String>[];

  /// Whether every field currently holds a digit.
  bool get isComplete => _field?.isComplete ?? false;

  /// Moves the field to [status], playing the matching animation.
  void setStatus(OtpStackStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  /// Fills the fields from [value], keeping only the first digits.
  ///
  /// Does nothing until the field is attached (i.e. after the first build).
  void setOtp(String value) {
    _field?.setOtp(value);
  }

  /// Clears every field. The status is left untouched.
  void clear() {
    _field?.clearDigits();
  }

  /// Clears the fields and returns the field to [OtpStackStatus.idle].
  void reset() {
    _field?.clearDigits();
    if (_status != OtpStackStatus.idle) {
      _status = OtpStackStatus.idle;
      notifyListeners();
    }
  }

  @internal
  void attach(OtpStackFieldBinding field) {
    if (identical(_field, field)) return;
    _field?.detachController();
    _field = field;
    field.attachController(this);
  }

  @internal
  void detach(OtpStackFieldBinding field) {
    if (!identical(_field, field)) return;
    field.detachController();
    _field = null;
  }
}
