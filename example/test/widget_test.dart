import 'package:flutter_test/flutter_test.dart';
import 'package:otp_stack/otp_stack.dart';

import 'package:otp_stack_example/main.dart';

void main() {
  testWidgets('renders the verification screen', (tester) async {
    await tester.pumpWidget(const OtpStackExampleApp());

    expect(find.text('Verify your number'), findsOneWidget);
    expect(find.byType(OtpStackField), findsOneWidget);
  });
}
