import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_front/core/widgets/enter_search_field.dart';

void main() {
  testWidgets('submits a search only after the search action', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EnterSearchField(onSubmitted: submitted.add)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'condomínio');
    expect(submitted, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, ['condomínio']);
  });
}
