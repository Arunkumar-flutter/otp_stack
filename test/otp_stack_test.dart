import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otp_stack/otp_stack.dart';

Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('OtpStackStatus exposes the four states', () {
    expect(OtpStackStatus.values, <OtpStackStatus>[
      OtpStackStatus.idle,
      OtpStackStatus.verifying,
      OtpStackStatus.success,
      OtpStackStatus.error,
    ]);
  });

  testWidgets('renders one editable field per digit', (tester) async {
    await tester.pumpWidget(wrap(const OtpStackField(length: 4)));
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('changing length rebuilds the fields', (tester) async {
    await tester.pumpWidget(wrap(const OtpStackField(length: 4)));
    expect(find.byType(TextField), findsNWidgets(4));

    await tester.pumpWidget(wrap(const OtpStackField(length: 6)));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('reports changes and completion', (tester) async {
    final changes = <String>[];
    String? completed;

    await tester.pumpWidget(
      wrap(
        OtpStackField(
          onChanged: changes.add,
          onCompleted: (value) => completed = value,
        ),
      ),
    );

    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
      await tester.pump();
    }

    expect(changes.last, '123456');
    expect(completed, '123456');
  });

  testWidgets('fires onCompleted only once per completion', (tester) async {
    var completions = 0;

    await tester.pumpWidget(
      wrap(OtpStackField(onCompleted: (_) => completions++)),
    );

    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
      await tester.pump();
    }
    await tester.pump();

    expect(completions, 1);
  });

  testWidgets('paste fills every field', (tester) async {
    String? completed;

    await tester.pumpWidget(
      wrap(OtpStackField(onCompleted: (value) => completed = value)),
    );

    await tester.enterText(find.byType(TextField).first, '987654');
    await tester.pump();

    expect(completed, '987654');
    for (var i = 0; i < 6; i++) {
      expect(find.text('${9 - i}'), findsOneWidget);
    }
  });

  testWidgets('backspace on an empty field returns to the previous one', (
    tester,
  ) async {
    final changes = <String>[];

    await tester.pumpWidget(wrap(OtpStackField(onChanged: changes.add)));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1');
    await tester.pump();

    // Focus moved to field 1, which is still empty.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(changes.last, '');
    expect(find.text('1'), findsNothing);
  });

  testWidgets('verifying hides the inputs and shows a loader', (tester) async {
    await tester.pumpWidget(
      wrap(const OtpStackField(status: OtpStackStatus.verifying)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('fan positions match the reference math', (tester) async {
    await tester.pumpWidget(
      wrap(const OtpStackField(status: OtpStackStatus.verifying)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // fan complete

    const width = 800.0; // default test surface width
    const cardWidth = 46.0;
    const spread = 15.0;
    final centerLeft = (width - cardWidth) / 2;

    // fanLeft = centerLeft + side * 15, with side = i - 2.5 and draw order
    // [0, 5, 1, 4, 2, 3], exactly like the reference implementation.
    final expectedLefts = <double>[
      for (final i in const [0, 5, 1, 4, 2, 3]) centerLeft + (i - 2.5) * spread,
    ];

    final lefts = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .map((positioned) => positioned.left)
        .whereType<double>()
        .toList();

    for (final expected in expectedLefts) {
      expect(lefts, contains(expected));
    }
  });

  testWidgets('success stacks the cards and shows a checkmark', (tester) async {
    await tester.pumpWidget(
      wrap(const OtpStackField(status: OtpStackStatus.success)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    // Let the stack-completion callback flip `_stacking` off and rebuild.
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    // Exactly the two center cards show a check; the loading overlay is gone.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('success shows the center overlay only while stacking', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const OtpStackField(status: OtpStackStatus.success)),
    );

    await tester.pump();
    // Mid-collapse: the center overlay carries the check, the two center
    // cards are still empty (the reference's `stacking` phase).
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    // Once the collapse finishes the overlay disappears and the two center
    // cards take over the check (the reference's `success` phase).
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });

  testWidgets('error restores the editable inputs', (tester) async {
    await tester.pumpWidget(
      wrap(const OtpStackField(status: OtpStackStatus.error)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('controller drives the status', (tester) async {
    final controller = OtpStackController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(wrap(OtpStackField(controller: controller)));
    expect(find.byType(TextField), findsNWidgets(6));

    controller.setStatus(OtpStackStatus.verifying);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TextField), findsNothing);

    controller.setStatus(OtpStackStatus.idle);
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('controller sets and clears the value', (tester) async {
    final controller = OtpStackController();
    addTearDown(controller.dispose);

    String? completed;
    await tester.pumpWidget(
      wrap(
        OtpStackField(
          controller: controller,
          onCompleted: (value) => completed = value,
        ),
      ),
    );

    controller.setOtp('135790');
    await tester.pump();
    expect(controller.otp, '135790');
    expect(completed, '135790');

    controller.clear();
    await tester.pump();
    expect(controller.otp, '');
  });

  test('rejects providing both status and controller', () {
    final controller = OtpStackController();
    addTearDown(controller.dispose);

    expect(
      () => OtpStackField(status: OtpStackStatus.idle, controller: controller),
      throwsAssertionError,
    );
  });

  testWidgets('enabled false disables the fields', (tester) async {
    await tester.pumpWidget(wrap(const OtpStackField(enabled: false)));
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.enabled, isFalse);
  });

  testWidgets('readOnly makes the fields non-editable', (tester) async {
    await tester.pumpWidget(wrap(const OtpStackField(readOnly: true)));
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.readOnly, isTrue);
  });

  testWidgets('custom inputFormatters allow letters', (tester) async {
    await tester.pumpWidget(
      wrap(
        OtpStackField(
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          ],
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'A');
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('defaults to one-time-code autofill', (tester) async {
    await tester.pumpWidget(wrap(const OtpStackField()));
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
  });

  testWidgets('renders errorText under the field', (tester) async {
    await tester.pumpWidget(
      wrap(const OtpStackField(errorText: 'Invalid code')),
    );
    expect(find.text('Invalid code'), findsOneWidget);
  });

  testWidgets('applies the semantic label', (tester) async {
    await tester.pumpWidget(
      wrap(const OtpStackField(semanticLabel: 'One-time code')),
    );
    expect(find.bySemanticsLabel('One-time code'), findsOneWidget);
  });

  testWidgets('onRestored fires after the error animation', (tester) async {
    OtpStackStatus? restored;
    await tester.pumpWidget(
      wrap(
        OtpStackField(
          status: OtpStackStatus.error,
          onRestored: (status) => restored = status,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(restored, OtpStackStatus.idle);
  });
}
