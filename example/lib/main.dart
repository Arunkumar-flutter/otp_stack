import 'dart:async';

import 'package:flutter/material.dart';

import 'package:otp_stack/otp_stack.dart';

void main() {
  runApp(const OtpStackExampleApp());
}

class OtpStackExampleApp extends StatelessWidget {
  const OtpStackExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'otp_stack example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6675FF)),
        useMaterial3: true,
      ),
      home: const OtpVerificationScreen(),
    );
  }
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _controller = OtpStackController();
  String _otp = '';

  /// Number of pin boxes — switch between 4 and 6 to see the animations adapt.
  int _length = 6;

  @override
  void initState() {
    super.initState();
    // Rebuild when the controller status changes so the UI follows the
    // animation (verifying -> success / error -> idle).
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// The controller owns the status, so the UI reads it from there.
  OtpStackStatus get _status => _controller.status;

  /// DEMO ONLY: replace this with your real API/repository call.
  Future<bool> _verify(String otp) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return otp != '000000';
  }

  Future<void> _onCompleted(String otp) async {
    setState(() => _otp = otp);

    // 1. Tell the package to fan the cards out and show the loading border.
    _controller.setStatus(OtpStackStatus.verifying);

    final valid = await _verify(otp);
    if (!mounted) return;

    // 2. Tell the package the result; it plays the matching animation.
    _controller.setStatus(
      valid ? OtpStackStatus.success : OtpStackStatus.error,
    );
  }

  void _retry() => _controller.reset();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8ECFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF5865E8),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify your number',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF161A32),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter the 6-digit code sent to your phone',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF777D95), fontSize: 14),
                ),
                const SizedBox(height: 42),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 4, label: Text('4 digits')),
                    ButtonSegment(value: 6, label: Text('6 digits')),
                  ],
                  selected: {_length},
                  onSelectionChanged: (selection) {
                    setState(() => _length = selection.first);
                    _controller.reset();
                  },
                ),
                const SizedBox(height: 24),
                OtpStackField(
                  length: _length,
                  controller: _controller,
                  autofocus: true,
                  semanticLabel: 'One-time code',
                  // The field auto-restores to editable cards after an error;
                  // keep the controller status in sync.
                  onRestored: (_) => _controller.setStatus(OtpStackStatus.idle),
                  onChanged: (otp) => setState(() => _otp = otp),
                  onCompleted: _onCompleted,
                ),
                const SizedBox(height: 20),
                _statusText(),
                const SizedBox(height: 18),
                if (_status == OtpStackStatus.idle)
                  TextButton(onPressed: () {}, child: const Text('Resend OTP')),
                if (_status == OtpStackStatus.success)
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue'),
                  ),
                if (_status == OtpStackStatus.error)
                  TextButton(
                    onPressed: _retry,
                    child: const Text('Clear code and try again'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusText() {
    final (title, subtitle, color) = switch (_status) {
      OtpStackStatus.idle => (
        'Enter your code',
        _otp.isEmpty ? 'Your code will be verified securely.' : 'Code: $_otp',
        const Color(0xFF777D95),
      ),
      OtpStackStatus.verifying => (
        'Verifying OTP...',
        'Please wait a moment.',
        const Color(0xFF6675FF),
      ),
      OtpStackStatus.success => (
        'OTP verified!',
        'Your number has been verified.',
        const Color(0xFF20A56B),
      ),
      OtpStackStatus.error => (
        'Invalid OTP',
        'Enter any code except 000000 to see the demo succeed.',
        Colors.redAccent,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: Column(
        key: ValueKey(_status),
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777D95), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
