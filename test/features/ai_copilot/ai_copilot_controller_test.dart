import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/models/ai_config.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/ai/services/ai_config_service.dart';
import 'package:ordo/core/ai/services/ai_task_parser.dart';
import 'package:ordo/core/ai/services/ai_task_persistence_service.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/features/ai_copilot/models/ai_chat_message.dart';
import 'package:ordo/features/ai_copilot/providers/ai_copilot_controller.dart';

class FakeAiConfigService implements AiConfigService {
  @override
  Future<AiConfig> loadConfig([AiProviderType? targetProvider]) async =>
      AiConfig.initial();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAiTaskParser implements AiTaskParser {
  FakeAiTaskParser({this.resultToReturn});
  AiTaskParseResult? resultToReturn;
  String? lastInput;

  @override
  Future<AiTaskParseResult> parse(
    String input, {
    AiConfig? config,
    DateTime? now,
    String locale = 'zh',
  }) async {
    lastInput = input;
    return resultToReturn ?? AiTaskParseResult.fallback(input);
  }

  @override
  AiTaskParseResult parseRawResponse(
    String response, {
    String? originalInput,
    String locale = 'zh',
  }) {
    return AiTaskParseResult.fromJson({});
  }
}

class FakeAiTaskPersistenceService implements AiTaskPersistenceService {
  AiTaskParseResult? lastPersistedResult;
  int persistCallCount = 0;

  @override
  Future<AiTaskPersistenceResult> persist(
    AiTaskParseResult parseResult, {
    String? projectId,
    String? inboxDisplayName = '收件箱',
    int? defaultTagColor,
  }) async {
    persistCallCount++;
    lastPersistedResult = parseResult;
    return AiTaskPersistenceResult(
      parentTask: Task(
        id: 't-1',
        projectId: 'inbox',
        title: parseResult.title,
        description: parseResult.description ?? '',
        notes: '',
        status: TaskStatus.todo,
        priority: parseResult.taskPriority,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAiConfigService fakeConfigService;
  late FakeAiTaskParser fakeParser;
  late FakeAiTaskPersistenceService fakePersistenceService;
  late ProviderContainer container;

  setUp(() {
    fakeConfigService = FakeAiConfigService();
    fakeParser = FakeAiTaskParser();
    fakePersistenceService = FakeAiTaskPersistenceService();

    container = ProviderContainer(
      overrides: [
        aiConfigServiceProvider.overrideWithValue(fakeConfigService),
        aiTaskParserProvider.overrideWithValue(fakeParser),
        aiTaskPersistenceServiceProvider.overrideWithValue(
          fakePersistenceService,
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AiCopilotController 业务流程与状态管理', () {
    test('初始状态消息列表为空且 isLoading=false', () {
      final state = container.read(aiCopilotControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('sendMessage 成功解析后生成用户消息与任务提案消息', () async {
      const parseResult = AiTaskParseResult(
        title: '明天下午3点团队周会',
        priority: 2,
        substeps: [],
      );

      fakeParser.resultToReturn = parseResult;

      final controller = container.read(aiCopilotControllerProvider.notifier);
      await controller.sendMessage('明天下午3点团队周会');

      final state = container.read(aiCopilotControllerProvider);
      expect(state.messages.length, 2);
      expect(state.messages[0].type, AiChatMessageType.user);
      expect(state.messages[0].content, '明天下午3点团队周会');

      expect(state.messages[1].type, AiChatMessageType.taskProposal);
      expect(state.messages[1].proposal?.title, '明天下午3点团队周会');
      expect(state.messages[1].proposal?.priority, 2);
      expect(state.isLoading, isFalse);
    });

    test('toggleSubstep 能够正确选中与取消子步骤', () async {
      final parseResult = const AiTaskParseResult(
        title: '开发新功能',
        priority: 1,
        substeps: [
          AiSubstep(title: '需求分析', sortOrder: 0),
          AiSubstep(title: '接口定义', sortOrder: 1),
        ],
      );

      fakeParser.resultToReturn = parseResult;

      final controller = container.read(aiCopilotControllerProvider.notifier);
      await controller.sendMessage('开发新功能');

      final msgId = container.read(aiCopilotControllerProvider).messages[1].id;

      // 默认所有子步骤均被选中：{0, 1}
      expect(
        container
            .read(aiCopilotControllerProvider)
            .messages[1]
            .selectedSubstepIndices,
        const {0, 1},
      );

      // 点击步骤 0，取消选中
      controller.toggleSubstep(msgId, 0);
      var proposalMsg = container.read(aiCopilotControllerProvider).messages[1];
      expect(proposalMsg.selectedSubstepIndices, const {1});

      // 再次点击步骤 0，恢复选中
      controller.toggleSubstep(msgId, 0);
      proposalMsg = container.read(aiCopilotControllerProvider).messages[1];
      expect(proposalMsg.selectedSubstepIndices, const {0, 1});
    });

    test('confirmTaskProposal 只持久化选中的子步骤并标记为已添加', () async {
      final parseResult = const AiTaskParseResult(
        title: '测试任务',
        priority: 1,
        substeps: [
          AiSubstep(title: '步骤 1', sortOrder: 0),
          AiSubstep(title: '步骤 2', sortOrder: 1),
        ],
      );

      fakeParser.resultToReturn = parseResult;

      final controller = container.read(aiCopilotControllerProvider.notifier);
      await controller.sendMessage('测试任务');

      final msgId = container.read(aiCopilotControllerProvider).messages[1].id;
      // 取消勾选步骤 2 (index 1)
      controller.toggleSubstep(msgId, 1);

      // 点击确认入库
      final result = await controller.confirmTaskProposal(msgId);
      expect(result, isNotNull);

      // 验证 persistence service 收到的 proposal 中只有步骤 1
      final savedProposal = fakePersistenceService.lastPersistedResult!;
      expect(savedProposal.substeps.length, 1);
      expect(savedProposal.substeps.first.title, '步骤 1');

      // 验证卡片状态已流转为已添加
      final updatedMsg = container
          .read(aiCopilotControllerProvider)
          .messages[1];
      expect(updatedMsg.isPersisted, isTrue);

      // 二次点击确认不应重复执行持久化
      await controller.confirmTaskProposal(msgId);
      expect(fakePersistenceService.persistCallCount, 1);
    });

    test('updateProposal 实时更新任务提案属性', () async {
      const initial = AiTaskParseResult(
        title: '原标题',
        priority: 0,
        substeps: [AiSubstep(title: '步骤 A', sortOrder: 0)],
      );
      fakeParser.resultToReturn = initial;

      final controller = container.read(aiCopilotControllerProvider.notifier);
      await controller.sendMessage('原标题');

      final msgId = container.read(aiCopilotControllerProvider).messages[1].id;

      // 行内就地修改提案
      const modified = AiTaskParseResult(
        title: '新标题',
        priority: 3,
        substeps: [
          AiSubstep(title: '步骤 A-新', sortOrder: 0),
          AiSubstep(title: '步骤 B', sortOrder: 1),
        ],
      );

      controller.updateProposal(msgId, modified);

      final updatedMsg = container
          .read(aiCopilotControllerProvider)
          .messages[1];
      expect(updatedMsg.proposal?.title, '新标题');
      expect(updatedMsg.proposal?.priority, 3);
      expect(updatedMsg.proposal?.substeps.length, 2);
    });

    test('discardProposal 标记提案为已放弃', () async {
      const initial = AiTaskParseResult(title: '待放弃任务', priority: 0);
      fakeParser.resultToReturn = initial;

      final controller = container.read(aiCopilotControllerProvider.notifier);
      await controller.sendMessage('待放弃任务');

      final msgId = container.read(aiCopilotControllerProvider).messages[1].id;
      controller.discardProposal(msgId);

      final discardedMsg = container
          .read(aiCopilotControllerProvider)
          .messages[1];
      expect(discardedMsg.isDiscarded, isTrue);
    });

    test('clearChat 清空消息列表', () async {
      const initial = AiTaskParseResult(title: '测试任务', priority: 0);
      fakeParser.resultToReturn = initial;

      final controller = container.read(aiCopilotControllerProvider.notifier);
      await controller.sendMessage('测试任务');

      expect(container.read(aiCopilotControllerProvider).messages, isNotEmpty);

      controller.clearChat();

      expect(container.read(aiCopilotControllerProvider).messages, isEmpty);
    });
  });
}
