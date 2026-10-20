import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otp_stack/otp_stack.dart';
import 'package:otp_stack_example/main.dart';

void main() {
  testWidgets('renders the verification screen', (tester) async {
    await tester.pumpWidget(const OtpStackExampleApp());

    expect(find.text('Verify your number'), findsOneWidget);
    expect(find.byType(OtpStackField), findsOneWidget);
  });

  testWidgets('typing a full code starts the verification animation',
      (tester) async {
    await tester.pumpWidget(const OtpStackExampleApp());
    expect(find.byType(TextField), findsNWidgets(6));

    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
      await tester.pump();
    }

    // onCompleted must drive the controller so the cards fan out.
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the demo API resolve and the success animation finish.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });
}
