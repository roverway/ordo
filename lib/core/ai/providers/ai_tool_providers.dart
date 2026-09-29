import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordo/core/ai/services/ai_config_service.dart';
import 'package:ordo/core/ai/services/ai_tool_runner.dart';
import 'package:ordo/core/ai/tools/ai_tool_registry.dart';
import 'package:ordo/features/projects/project_providers.dart';

/// Provider for [AiToolRegistry] containing standard tools.
final aiToolRegistryProvider = Provider<AiToolRegistry>((ref) {
  // Ensure todo repository is accessible if initialized
  ref.watch(todoRepositoryProvider);
  return AiToolRegistry.standard();
});

/// Provider for [AiToolRunner] coordinating agent multi-step loops.
final aiToolRunnerProvider = Provider<AiToolRunner>((ref) {
  final client = ref.watch(aiClientProvider);
  final registry = ref.watch(aiToolRegistryProvider);
  return AiToolRunner(aiClient: client, registry: registry);
});
