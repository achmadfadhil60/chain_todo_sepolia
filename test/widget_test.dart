import 'package:flutter_test/flutter_test.dart';
import 'package:chain_todo_app/main.dart';

void main() {
  testWidgets('Aplikasi ChainTodo dapat dimuat', (WidgetTester tester) async {
    await tester.pumpWidget(const ChainTodoApp());
    expect(find.text('ChainTodo (Sepolia)'), findsOneWidget);
  });
}