import 'package:flutter/foundation.dart' show internal;

import 'otp_stack_controller.dart';

/// Internal contract between `OtpStackField` and `OtpStackController`.
///
/// This exists so the field's [State] class can stay private. It is **not**
/// part of the package's public API and must not be imported by consumers.
@internal
abstract class OtpStackFieldBinding {
  /// The current OTP string.
  String get otp;

  /// The current digits, one entry per field.
  List<String> get digits;

  /// Whether every field currently holds a digit.
  bool get isComplete;

  /// Fills the fields from [value], keeping only the first digits.
  void setOtp(String value);

  /// Clears every field.
  void clearDigits();

  /// Attaches [controller] so status changes are observed.
  void attachController(OtpStackController controller);

  /// Detaches the current controller.
  void detachController();
}
