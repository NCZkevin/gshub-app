import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/features/logs/presentation/logs_provider.dart';
import 'package:sysapp/features/logs/presentation/logs_screen.dart';
import 'package:sysapp/shared/domain/app_models.dart';

class _FakeLogsNotifier extends LogsNotifier {
  @override
  Future<LogsState> build() async {
    return LogsState(
      files: [
        LogFileInfo(
          name: 'robot.log',
          size: 2048,
          modifiedTime: DateTime(2026, 6, 23, 10, 30),
        ),
      ],
      selected: 'robot.log',
      content: List.generate(
        12000,
        (i) => '${i.isEven ? 'INFO' : 'ERROR'} line $i robot status payload',
      ).join('\n'),
    );
  }
}

void main() {
  testWidgets('logs screen renders a selected log without framework errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [logsProvider.overrideWith(_FakeLogsNotifier.new)],
        child: const MaterialApp(home: LogsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('robot.log'), findsWidgets);
    expect(find.textContaining('robot status payload'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
