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

  testWidgets('success stacks the cards and shows a checkmark', (tester) async {
    await tester.pumpWidget(
      wrap(const OtpStackField(status: OtpStackStatus.success)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
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
}
