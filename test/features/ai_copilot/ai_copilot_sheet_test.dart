import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/ai/services/ai_task_parser.dart';
import 'package:ordo/core/ai/services/ai_task_persistence_service.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/features/ai_copilot/providers/ai_copilot_controller.dart';
import 'package:ordo/features/ai_copilot/views/ai_copilot_sheet.dart';
import 'package:ordo/features/ai_copilot/widgets/ai_chat_input_box.dart';
import 'package:ordo/features/ai_copilot/widgets/ai_prompt_capsule.dart';
import 'package:ordo/features/ai_copilot/widgets/ai_task_proposal_card.dart';

class _FakeAiTaskParser implements AiTaskParser {
  @override
  Future<AiTaskParseResult> parse(
    String input, {
    dynamic config,
    DateTime? now,
  }) async {
    return AiTaskParseResult(
      title: input,
      description: '自动解析',
      priority: 3,
      tags: const ['工作'],
      substeps: const [
        AiSubstep(title: '步骤 1', sortOrder: 0),
        AiSubstep(title: '步骤 2', sortOrder: 1),
      ],
    );
  }

  @override
  AiTaskParseResult parseRawResponse(String response, {String? originalInput}) {
    return AiTaskParseResult(title: originalInput ?? '任务');
  }
}

class _FakePersistenceService implements AiTaskPersistenceService {
  @override
  Future<AiTaskPersistenceResult> persist(
    AiTaskParseResult proposal, {
    String? projectId,
    int? defaultTagColor,
    String? inboxDisplayName,
  }) async {
    return AiTaskPersistenceResult(
      parentTask: Task(
        id: 'task-test-1',
        projectId: 'inbox',
        title: proposal.title,
        description: '',
        notes: '',
        status: TaskStatus.todo,
        priority: proposal.taskPriority,
        sortOrder: 0,
        createdAt: 0,
        updatedAt: 0,
        deleted: 0,
      ),
      subtasks: const [],
      tags: const [],
    );
  }
}

Widget _buildTestApp({
  required Widget child,
  Size screenSize = const Size(390, 844),
  dynamic overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides is List ? overrides.cast() : const [],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('AiPromptCapsule Tests', () {
    testWidgets('renders icon and label with pill shape', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _buildTestApp(
          child: AiPromptCapsule(
            icon: Icons.calendar_today,
            label: '帮我规划今天',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('帮我规划今天'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);

      await tester.tap(find.text('帮我规划今天'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('AiChatInputBox Tests', () {
    testWidgets('send button is disabled when input is empty or whitespace', (
      tester,
    ) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        _buildTestApp(
          child: AiChatInputBox(
            controller: controller,
            focusNode: focusNode,
            hintText: '输入...',
            onSubmitted: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sendButton = tester.widget<IconButton>(
        find.byKey(AiChatInputBox.sendButtonKey),
      );
      expect(sendButton.onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      final sendButtonAfterWhitespace = tester.widget<IconButton>(
        find.byKey(AiChatInputBox.sendButtonKey),
      );
      expect(sendButtonAfterWhitespace.onPressed, isNull);
    });

    testWidgets('send button sends text and clears field when submitted', (
      tester,
    ) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      String submittedText = '';

      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        _buildTestApp(
          child: AiChatInputBox(
            controller: controller,
            focusNode: focusNode,
            hintText: '输入...',
            onSubmitted: (text) => submittedText = text,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '请帮我写周报');
      await tester.pump();

      final sendButton = tester.widget<IconButton>(
        find.byKey(AiChatInputBox.sendButtonKey),
      );
      expect(sendButton.onPressed, isNotNull);

      await tester.tap(find.byKey(AiChatInputBox.sendButtonKey));
      await tester.pump();

      expect(submittedText, equals('请帮我写周报'));
      expect(controller.text, isEmpty);
    });

    testWidgets('submitting via onSubmitted triggers send', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      String submittedText = '';

      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        _buildTestApp(
          child: AiChatInputBox(
            controller: controller,
            focusNode: focusNode,
            hintText: '输入...',
            onSubmitted: (text) => submittedText = text,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '回车发送测试');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      expect(submittedText, equals('回车发送测试'));
      expect(controller.text, isEmpty);
    });

    testWidgets('disabled state prevents typing and sending', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        _buildTestApp(
          child: AiChatInputBox(
            controller: controller,
            focusNode: focusNode,
            hintText: '输入...',
            enabled: false,
            onSubmitted: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });
  });

  group('AiCopilotSheet Views & Interactions', () {
    testWidgets(
      'opens mobile BottomSheet on narrow screen with grabber and close button',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            screenSize: const Size(390, 844),
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => AiCopilotSheet.show(context),
                  child: const Text('Open Copilot'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Copilot'));
        await tester.pumpAndSettle();

        expect(find.byType(AiCopilotSheet), findsOneWidget);
        expect(find.byKey(AiCopilotSheet.grabberKey), findsOneWidget);
        expect(find.byKey(AiCopilotSheet.closeButtonKey), findsOneWidget);

        // Close it
        await tester.tap(find.byKey(AiCopilotSheet.closeButtonKey));
        await tester.pumpAndSettle();

        expect(find.byType(AiCopilotSheet), findsNothing);
      },
    );

    testWidgets(
      'opens side sheet on desktop/tablet (>= 600dp) with right margin and no grabber',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          _buildTestApp(
            screenSize: const Size(1024, 768),
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => AiCopilotSheet.show(context),
                  child: const Text('Open Side'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Side'));
        await tester.pumpAndSettle();

        expect(find.byKey(AiCopilotSheet.grabberKey), findsNothing);
        expect(find.byKey(AiCopilotSheet.closeButtonKey), findsOneWidget);
      },
    );

    testWidgets('tapping prompt capsule fills input box and requests focus', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(child: const AiCopilotSheet()));
      await tester.pumpAndSettle();

      expect(find.text('生成周报'), findsOneWidget);
      await tester.tap(find.text('生成周报'));
      await tester.pumpAndSettle();

      expect(find.text('生成周报'), findsWidgets);
    });

    testWidgets('clear button clears all messages', (tester) async {
      final fakeParser = _FakeAiTaskParser();
      final fakePersistence = _FakePersistenceService();

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            aiTaskParserProvider.overrideWithValue(fakeParser),
            aiTaskPersistenceServiceProvider.overrideWithValue(fakePersistence),
          ],
          child: const AiCopilotSheet(),
        ),
      );
      await tester.pumpAndSettle();

      // Send a message
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();
      await tester.tap(find.byKey(AiChatInputBox.sendButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Test message'), findsWidgets);
      expect(find.byKey(AiCopilotSheet.clearButtonKey), findsOneWidget);

      await tester.tap(find.byKey(AiCopilotSheet.clearButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Test message'), findsNothing);
      expect(find.byKey(AiCopilotSheet.clearButtonKey), findsNothing);
    });

    testWidgets(
      'renders proposal card and confirms task persistence to database',
      (tester) async {
        final fakeParser = _FakeAiTaskParser();
        final fakePersistence = _FakePersistenceService();

        await tester.pumpWidget(
          _buildTestApp(
            overrides: [
              aiTaskParserProvider.overrideWithValue(fakeParser),
              aiTaskPersistenceServiceProvider.overrideWithValue(
                fakePersistence,
              ),
            ],
            child: const AiCopilotSheet(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. 发送自然语言任务
        await tester.enterText(find.byType(TextField), '明天准备述职汇报');
        await tester.pump();
        await tester.tap(find.byKey(AiChatInputBox.sendButtonKey));
        await tester.pumpAndSettle();

        // 2. 确认卡片渲染
        expect(find.byType(AiTaskProposalCard), findsOneWidget);
        expect(find.text('建议任务'), findsOneWidget);
        expect(find.text('明天准备述职汇报'), findsWidgets);
        expect(find.text('添加到待办'), findsOneWidget);

        // 3. 点击"添加到待办"
        await tester.tap(find.text('添加到待办'));
        await tester.pumpAndSettle();

        // 4. 确认置灰与"已添加"状态
        expect(find.text('已添加'), findsOneWidget);
        expect(find.text('添加到待办'), findsNothing);
      },
    );
  });
}
