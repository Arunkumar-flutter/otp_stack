import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'otp_border_painter.dart';
import 'otp_stack_binding.dart';
import 'otp_stack_controller.dart';
import 'otp_stack_status.dart';

/// The internal rendering mode of [OtpStackField].
enum _DisplayMode {
  /// Editable input fields.
  input,

  /// Fanned-out / stacked cards.
  fan,
}

/// Keeps each field to a single character, while still letting a multi-digit
/// paste through so the widget can distribute it across the fields.
///
/// A paste drops several characters in at once (the new value is longer than
/// the old one by more than one), so it is passed through untouched. Typing a
/// second digit into a field that already holds one replaces that digit
/// instead of appending to it.
class _OtpFieldFormatter extends TextInputFormatter {
  const _OtpFieldFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // A paste replaces the whole value with several characters at once.
    if (text.length > oldValue.text.length + 1) {
      return newValue;
    }

    // Typing into a field that already holds a digit replaces it.
    if (text.length > 1) {
      final last = text.characters.last;
      return TextEditingValue(
        text: last,
        selection: TextSelection.collapsed(offset: last.length),
      );
    }

    return newValue;
  }
}

/// An animated OTP input that fans its cards out while verifying and stacks
/// them into a single success card.
///
/// The widget is intentionally dumb about the backend: the app owns the
/// [OtpStackStatus] and the package animates accordingly.
///
/// ```dart
/// OtpStackField(
///   length: 6,
///   status: _status,
///   onChanged: (otp) => setState(() => _otp = otp),
///   onCompleted: (otp) {
///     setState(() => _status = OtpStackStatus.verifying);
///     verify(otp).then((ok) {
///       setState(() => _status = ok
///           ? OtpStackStatus.success
///           : OtpStackStatus.error);
///     });
///   },
/// )
/// ```
///
/// Pass either [status] or [controller], not both. When [controller] is
/// provided it owns the status and takes precedence.
class OtpStackField extends StatefulWidget {
  /// Creates an animated OTP input.
  const OtpStackField({
    super.key,
    this.length = 6,
    this.status,
    this.controller,
    this.onChanged,
    this.onCompleted,
    this.onRestored,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.autofillHints = const [AutofillHints.oneTimeCode],
    this.textInputAction,
    this.cursorColor,
    this.semanticLabel,
    this.errorText,
    this.errorColor = const Color(0xFFE15A5A),
    this.cardWidth = 46,
    this.cardHeight = 58,
    this.cardGap = 4,
    this.height = 86,
    this.fanSpread = 15,
    this.primaryColor = const Color(0xFF6675FF),
    this.successColor = const Color(0xFF20A56B),
    this.textStyle = const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    this.cardTextStyle = const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  }) : assert(length > 0, 'length must be greater than 0'),
       assert(
         controller == null || status == null,
         'Provide either `status` or `controller`, not both.',
       );

  /// Number of OTP digits.
  final int length;

  /// Current verification status.
  ///
  /// Ignored when [controller] is provided. When omitted (and no controller is
  /// given) the field starts in [OtpStackStatus.idle].
  final OtpStackStatus? status;

  /// Optional controller to drive the status and value programmatically.
  ///
  /// When provided, it takes precedence over the [status] argument.
  final OtpStackController? controller;

  /// Called with the full OTP string whenever a digit changes.
  final ValueChanged<String>? onChanged;

  /// Called once each time the OTP becomes complete.
  final ValueChanged<String>? onCompleted;

  /// Called when the widget finishes restoring the editable cards after an
  /// error. Use it to set your own status back to [OtpStackStatus.idle].
  final ValueChanged<OtpStackStatus>? onRestored;

  /// Whether to focus the first field as soon as the widget is built.
  final bool autofocus;

  /// Whether the fields accept input. When `false` the cards are disabled.
  final bool enabled;

  /// Whether the fields are read-only (focusable but not editable).
  final bool readOnly;

  /// Whether to hide the entered digits.
  final bool obscureText;

  /// Keyboard type for the input fields.
  final TextInputType keyboardType;

  /// Formatters applied to each field.
  ///
  /// Defaults to digits only. Provide your own list to allow other characters
  /// (for example an alphanumeric code).
  final List<TextInputFormatter>? inputFormatters;

  /// Autofill hints, used to trigger SMS/email one-time-code autofill.
  ///
  /// Defaults to [AutofillHints.oneTimeCode].
  final Iterable<String>? autofillHints;

  /// Overrides the default `TextInputAction` (next, or done on the last field).
  final TextInputAction? textInputAction;

  /// Cursor color. Defaults to [primaryColor].
  final Color? cursorColor;

  /// Accessibility label announced for the whole field.
  ///
  /// Because the widget renders one `TextField` per digit, setting this label
  /// helps screen readers present it as a single one-time code.
  final String? semanticLabel;

  /// Optional message shown under the field (for example on an error).
  final String? errorText;

  /// Color of [errorText].
  final Color errorColor;

  /// Width of a single card in the fanned / stacked layout.
  final double cardWidth;

  /// Height of a single card.
  final double cardHeight;

  /// Horizontal gap between cards in the fanned / stacked layout.
  final double cardGap;

  /// Total height of the field.
  final double height;

  /// How far the outer cards spread from the center, in logical pixels.
  final double fanSpread;

  /// Accent color used for focus and the verifying border.
  final Color primaryColor;

  /// Color used for the success state.
  final Color successColor;

  /// Text style of the digits while editing.
  final TextStyle textStyle;

  /// Text style of the digits on the fanned / stacked cards.
  final TextStyle cardTextStyle;

  @override
  State<OtpStackField> createState() => _OtpStackFieldState();
}

/// State for [OtpStackField].
///
/// Private; the [OtpStackController] talks to it through
/// [OtpStackFieldBinding].
class _OtpStackFieldState extends State<OtpStackField>
    with TickerProviderStateMixin
    implements OtpStackFieldBinding {
  static final RegExp _nonDigits = RegExp(r'\D');

  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  late final AnimationController _fanController;
  late final AnimationController _stackController;
  late final AnimationController _borderController;

  OtpStackStatus _status = OtpStackStatus.idle;
  _DisplayMode _mode = _DisplayMode.input;

  /// True while the success cards are still collapsing into the center card.
  /// Mirrors the reference's `stacking` phase (distinct from `success`).
  bool _stacking = false;

  bool _lastNotifiedComplete = false;
  int _errorToken = 0;

  OtpStackController? _controllerRef;
  VoidCallback? _controllerListener;

  /// Whether the default digits-only formatter is in use.
  bool get _digitsOnly => widget.inputFormatters == null;

  /// The current OTP string.
  @override
  String get otp => _controllers.map((c) => c.text).join();

  /// The current digits, one entry per field.
  @override
  List<String> get digits =>
      List<String>.unmodifiable(_controllers.map((c) => c.text));

  /// Whether every field holds a digit.
  @override
  bool get isComplete =>
      _controllers.length == widget.length &&
      _controllers.every((c) => c.text.isNotEmpty);

  OtpStackStatus get _resolvedStatus =>
      widget.controller?.status ?? widget.status ?? OtpStackStatus.idle;

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
    _status = _resolvedStatus;

    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());

    _fanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _stackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    if (_status != OtpStackStatus.idle) {
      _handleStatusChange(_status);
    } else if (widget.autofocus) {
      _focusFirstAfterFrame();
    }
  }

  @override
  void didUpdateWidget(covariant OtpStackField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.length != oldWidget.length) {
      _syncLength();
    }

    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }

    final resolved = _resolvedStatus;
    if (resolved != _status) {
      _handleStatusChange(resolved);
    }
  }

  @override
  void dispose() {
    _detachController();
    widget.controller?.detach(this);

    _fanController.dispose();
    _stackController.dispose();
    _borderController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Controller wiring
  // ---------------------------------------------------------------------------

  @override
  void attachController(OtpStackController controller) {
    _detachController();
    _controllerRef = controller;
    _controllerListener = _onControllerChanged;
    controller.addListener(_controllerListener!);
  }

  @override
  void detachController() => _detachController();

  void _detachController() {
    if (_controllerRef != null && _controllerListener != null) {
      _controllerRef!.removeListener(_controllerListener!);
    }
    _controllerRef = null;
    _controllerListener = null;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    final resolved = _resolvedStatus;
    if (resolved != _status) {
      _handleStatusChange(resolved);
    }
  }

  // ---------------------------------------------------------------------------
  // Length handling
  // ---------------------------------------------------------------------------

  void _syncLength() {
    while (_controllers.length > widget.length) {
      _controllers.removeLast().dispose();
      _focusNodes.removeLast().dispose();
    }
    while (_controllers.length < widget.length) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
  }

  // ---------------------------------------------------------------------------
  // Status handling
  // ---------------------------------------------------------------------------

  void _handleStatusChange(OtpStackStatus status) {
    if (!mounted) return;
    _status = status;
    _errorToken++; // Invalidate any in-flight error restore.

    switch (status) {
      case OtpStackStatus.idle:
        _stacking = false;
        _borderController.stop();
        _borderController.value = 0;
        _fanController.stop();
        _fanController.value = 0;
        _stackController.stop();
        _stackController.value = 0;
        setState(() => _mode = _DisplayMode.input);
        break;

      case OtpStackStatus.verifying:
        _stacking = false;
        _unfocusAll();
        setState(() => _mode = _DisplayMode.fan);
        _fanController.forward(from: 0).then((_) {
          if (mounted && _status == OtpStackStatus.verifying) {
            _borderController.repeat();
          }
        });
        break;

      case OtpStackStatus.success:
        _borderController.stop();
        if (_fanController.status != AnimationStatus.completed) {
          _fanController.value = 1;
        }
        setState(() {
          _mode = _DisplayMode.fan;
          _stacking = true;
        });
        _stackController.forward(from: 0).then((_) {
          if (mounted) {
            setState(() => _stacking = false);
          }
        });
        break;

      case OtpStackStatus.error:
        _stacking = false;
        _borderController.stop();
        setState(() => _mode = _DisplayMode.fan);
        _runErrorRestore();
        break;
    }
  }

  Future<void> _runErrorRestore() async {
    final token = _errorToken;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || token != _errorToken) return;

    if (_fanController.value < 1) {
      await _fanController.forward();
      if (!mounted || token != _errorToken) return;
    }
    if (_stackController.value > 0) {
      await _stackController.reverse();
      if (!mounted || token != _errorToken) return;
    }

    await _fanController.reverse();
    if (!mounted || token != _errorToken) return;

    // A wrong code resets the fields so the user can enter a new one.
    for (final controller in _controllers) {
      controller.clear();
    }
    _notifyChange();

    setState(() => _mode = _DisplayMode.input);
    widget.onRestored?.call(OtpStackStatus.idle);
    if (widget.autofocus) {
      _focusFirstAfterFrame();
    }
  }

  // ---------------------------------------------------------------------------
  // Input handling
  // ---------------------------------------------------------------------------

  String _sanitize(String value) =>
      _digitsOnly ? value.replaceAll(_nonDigits, '') : value;

  void _onChanged(int index, String value) {
    if (!widget.enabled || _mode != _DisplayMode.input) return;

    final clean = _sanitize(value);

    // Pasting several characters into a single field fills every box from the
    // start, exactly like most banking apps do.
    if (clean.length > 1) {
      final pasted = clean.substring(0, widget.length);
      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text = i < pasted.length ? pasted[i] : '';
      }
      _notifyChange();
      if (pasted.length == widget.length) {
        _unfocusAll();
      } else {
        _focusNodes[pasted.length.clamp(0, widget.length - 1)].requestFocus();
      }
      return;
    }

    final digit = clean.isEmpty ? '' : clean[0];
    if (_controllers[index].text != digit) {
      _controllers[index].text = digit;
    }
    _notifyChange();

    if (digit.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (digit.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      _notifyChange();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _notifyChange() {
    final value = otp;
    widget.onChanged?.call(value);

    if (isComplete) {
      if (!_lastNotifiedComplete) {
        _lastNotifiedComplete = true;
        widget.onCompleted?.call(value);
      }
    } else {
      _lastNotifiedComplete = false;
    }
  }

  void _unfocusAll() {
    for (final node in _focusNodes) {
      node.unfocus();
    }
  }

  void _focusFirstAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Controller-facing helpers
  // ---------------------------------------------------------------------------

  @override
  void setOtp(String value) {
    final clean = _sanitize(value);
    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].text = i < clean.length ? clean[i] : '';
    }
    _notifyChange();
  }

  @override
  void clearDigits() {
    for (final controller in _controllers) {
      if (controller.text.isNotEmpty) {
        controller.clear();
      }
    }
    _notifyChange();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final field = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (constraints.minWidth.isFinite && constraints.minWidth > 0
                  ? constraints.minWidth
                  : 360.0);

        return SizedBox(
          height: widget.height,
          width: width,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _fanController,
              _stackController,
              _borderController,
            ]),
            builder: (context, _) {
              if (_mode == _DisplayMode.input) {
                return _buildInputRow();
              }
              return _buildFan(width);
            },
          ),
        );
      },
    );

    final column = widget.errorText == null
        ? field
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field,
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  widget.errorText!,
                  style: TextStyle(color: widget.errorColor, fontSize: 13),
                ),
              ),
            ],
          );

    if (widget.semanticLabel == null) {
      return column;
    }
    return Semantics(
      label: widget.semanticLabel,
      container: true,
      child: column,
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: List.generate(widget.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.cardGap / 2),
            child: _buildInputBox(i),
          ),
        );
      }),
    );
  }

  Widget _buildInputBox(int index) {
    return AnimatedBuilder(
      animation: _focusNodes[index],
      builder: (context, _) {
        final hasFocus = _focusNodes[index].hasFocus;
        return Container(
          height: widget.cardHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: hasFocus ? widget.primaryColor : const Color(0xFFDDE2F2),
              width: hasFocus ? 1.8 : 1.2,
            ),
          ),
          child: Focus(
            onKeyEvent: (node, event) => _onKey(index, event),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              keyboardType: widget.keyboardType,
              obscureText: widget.obscureText,
              autofillHints: widget.autofillHints,
              textAlign: TextAlign.center,
              style: widget.textStyle,
              cursorColor: widget.cursorColor ?? widget.primaryColor,
              textInputAction:
                  widget.textInputAction ??
                  (index == widget.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next),
              inputFormatters: [
                if (_digitsOnly) FilteringTextInputFormatter.digitsOnly,
                ...?widget.inputFormatters,
                const _OtpFieldFormatter(),
              ],
              maxLength: widget.length,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
              onChanged: (value) => _onChanged(index, value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFan(double width) {
    final length = widget.length;
    final cardWidth = widget.cardWidth;
    final cardHeight = widget.cardHeight;
    final gap = widget.cardGap;
    final half = (length - 1) / 2;

    final totalWidth = cardWidth * length + gap * (length - 1);
    final startLeft = (width - totalWidth) / 2;
    final centerLeft = (width - cardWidth) / 2;

    final fanT = Curves.easeOutCubic.transform(
      _fanController.value.clamp(0.0, 1.0),
    );
    final stackT = Curves.easeInCubic.transform(
      _stackController.value.clamp(0.0, 1.0),
    );

    // `isStacked` drives the collapsed position for the whole success state,
    // while `isStacking` marks the short collapse animation itself (the
    // reference's `stacking` phase) and only then shows the center overlay.
    final isStacked = _status == OtpStackStatus.success;
    final isStacking = _stacking;
    final isVerifying = _status == OtpStackStatus.verifying;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final i in _drawOrder(length))
          Builder(
            builder: (context) {
              final originalLeft = startLeft + i * (cardWidth + gap);
              final side = i - half;
              final targetLeft = centerLeft + side * widget.fanSpread;
              final fanLeft = originalLeft + (targetLeft - originalLeft) * fanT;
              final collapsedLeft = fanLeft + (centerLeft - fanLeft) * stackT;
              final fanAngle = side * 0.105 * fanT;
              final angle = fanAngle * (1 - stackT);

              final isCenter = _isCenterCard(i, length);
              final hideCenterDigit =
                  (isVerifying || isStacking || isStacked) && isCenter;

              return Positioned(
                left: isStacked ? collapsedLeft : fanLeft,
                top: 10 + side.abs() * 1.4 * (1 - fanT),
                child: Transform.rotate(
                  angle: angle,
                  child: _otpCard(
                    width: cardWidth,
                    height: cardHeight,
                    borderColor: _fanBorderColor(i, length),
                    child: isCenter && isStacked && !isStacking
                        ? Icon(
                            Icons.check_rounded,
                            color: widget.successColor,
                            size: 27,
                          )
                        : hideCenterDigit
                        ? const SizedBox.shrink()
                        : Text(
                            _controllers[i].text,
                            style: widget.cardTextStyle,
                          ),
                  ),
                ),
              );
            },
          ),
        if (isVerifying || isStacking)
          Positioned(
            left: centerLeft,
            top: 10,
            child: _otpCard(
              width: cardWidth,
              height: cardHeight,
              borderColor: widget.primaryColor,
              animatedBorder: true,
              child: isVerifying
                  ? SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: widget.primaryColor,
                      ),
                    )
                  : Icon(
                      Icons.check_rounded,
                      color: widget.successColor,
                      size: 27,
                    ),
            ),
          ),
      ],
    );
  }

  Color _fanBorderColor(int index, int length) {
    // Matches the reference: only the two center cards turn primary while
    // verifying; every other card (including during success/error) stays the
    // light blue used across the fan.
    if (_status == OtpStackStatus.verifying && _isCenterCard(index, length)) {
      return widget.primaryColor;
    }
    return const Color(0xFFABB8FF);
  }

  bool _isCenterCard(int index, int length) {
    if (length.isEven) {
      final middle = length ~/ 2;
      return index == middle - 1 || index == middle;
    }
    return index == length ~/ 2;
  }

  List<int> _drawOrder(int length) {
    final result = <int>[];
    var left = 0;
    var right = length - 1;
    var takeLeft = true;
    while (left <= right) {
      if (takeLeft) {
        result.add(left++);
      } else {
        result.add(right--);
      }
      takeLeft = !takeLeft;
    }
    return result;
  }

  Widget _otpCard({
    required double width,
    required double height,
    required Color borderColor,
    required Widget child,
    bool animatedBorder = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C5262B8),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: OtpBorderPainter(
          progress: _borderController.value,
          color: borderColor,
          animated: animatedBorder,
        ),
        child: Center(child: child),
      ),
    );
  }
}
