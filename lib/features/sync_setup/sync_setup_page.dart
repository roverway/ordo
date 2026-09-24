// 同步配置页（docs/60-sync-design.md §10，docs/50-ui-ux.md §5.7 `/settings/sync`）。
//
// 布局（对齐 50-ui-ux §5.7）：
// - 状态展示区（订阅 syncStateProvider）：同步中 spinner / 成功 + 上次同步时间
//   （本地时区格式化）/ 失败 + 红色错误信息 + 可重试提示；
// - 启用开关 + 远端类型（WebDAV / S3 兼容桶）；
// - 凭据表单（按类型动态显示）；
// - 自动同步设置（autoOnStart / autoOnEdit / wifiOnly）；
// - 操作区：测试连接 / 立即同步 / 保存。
//
// 视觉：复用 settings_page 的卡片分组样式（_SectionHeader / _SettingsCard）与
// AppTokens 令牌（50-ui-ux §2）；宽屏（≥600dp）表单居中限宽约 560。
//
// §11 时钟偏差确认：本页 initState 注册 confirmClockSkew 回调（弹确认框），
// dispose 时注销；页面自身不负责 SyncEngine/SyncTriggers 的释放（全局单例，
// 生命周期由 app 层管理）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/security/secure_store.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../core/utils/dates.dart';
import '../../shared/widgets/modern_segmented_control.dart';
import 'sync_setup_providers.dart';

/// 宽屏表单最大宽度（50-ui-ux §5.7：约 560dp）。
const double _kFormMaxWidth = 560;

/// 同步配置页（独立全屏路由）。
class SyncSetupPage extends StatelessWidget {
  const SyncSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncSettings)),
      body: const SyncSetupBody(),
    );
  }
}

/// 同步配置表单主内容（支持独立页面及宽屏模态侧边抽屉内嵌复用）。
class SyncSetupBody extends ConsumerStatefulWidget {
  const SyncSetupBody({super.key});

  @override
  ConsumerState<SyncSetupBody> createState() => _SyncSetupBodyState();
}

class _SyncSetupBodyState extends ConsumerState<SyncSetupBody> {
  final _serverUrl = TextEditingController();
  final _username = TextEditingController();
  final _secret = TextEditingController();
  final _bucket = TextEditingController();
  final _region = TextEditingController();
  final _prefix = TextEditingController();

  RemoteType _type = RemoteType.webdav;
  bool _enabled = false;
  bool _autoOnStart = false;
  bool _autoOnEdit = false;
  bool _wifiOnly = false;

  /// 是否已完成配置预填（只执行一次）。
  bool _loaded = false;

  /// 按钮进行中状态（禁用 + 行内 spinner）。
  bool _saving = false;
  bool _testing = false;

  /// 上次同步失败是否可重试（§12：网络/远端错误可退避重试）。
  bool _lastErrorRetryable = false;

  /// 时钟偏差确认持有者（initState 缓存，dispose 中不可用 ref）。
  late final ClockSkewConfirmHolder _skewHolder;

  @override
  void initState() {
    super.initState();
    // §11：注册时钟偏差确认回调（dispose 时注销）。
    _skewHolder = ref.read(clockSkewConfirmProvider);
    _skewHolder.callback = _confirmClockSkew;
  }

  @override
  void dispose() {
    _skewHolder.callback = null;
    _serverUrl.dispose();
    _username.dispose();
    _secret.dispose();
    _bucket.dispose();
    _region.dispose();
    _prefix.dispose();
    super.dispose();
  }

  /// §11 时钟偏差确认：远端与本地时间相差 >5min 时弹框询问，确认才继续。
  Future<bool> _confirmClockSkew() async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.syncClockSkewTitle),
        content: Text(l10n.syncClockSkewBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// 用当前配置预填表单（仅填入当前类型适用字段，另一类型字段清空）。
  void _applyConfig(SyncConfig config) {
    setState(() {
      _type = config.type;
      _enabled = config.enabled;
      _autoOnStart = config.autoOnStart;
      _autoOnEdit = config.autoOnEdit;
      _wifiOnly = config.wifiOnly;
      _fillTypeFields(config.type, config);
    });
  }

  /// 按 [type] 的字段集填入表单（从 [creds] 取已存值，无则清空）。
  void _fillTypeFields(RemoteType type, SyncConfig creds) {
    _serverUrl.text = creds.serverUrl ?? '';
    _username.text = creds.username ?? '';
    _secret.text = creds.secret ?? '';
    final isS3 = type == RemoteType.s3;
    _bucket.text = isS3 ? (creds.bucket ?? '') : '';
    _region.text = isS3 ? (creds.region ?? '') : '';
    _prefix.text = isS3 ? (creds.prefix ?? '') : '';
  }

  /// 切换远端类型：先同步清空全部字段，再异步重载新类型已存凭据。
  Future<void> _onTypeChanged(RemoteType newType) async {
    if (newType == _type) return;
    setState(() {
      _type = newType;
      _fillTypeFields(newType, const SyncConfig());
    });
    final store = ref.read(secureStoreProvider);
    SyncConfig? creds;
    try {
      creds = await store.readCreds(newType);
    } on SecureStoreException {
      creds = null;
    }
    if (!mounted || _type != newType) return;
    setState(() => _fillTypeFields(newType, creds ?? const SyncConfig()));
  }

  /// 表单 → SyncConfig。
  SyncConfig _buildConfig() {
    return SyncConfig(
      type: _type,
      enabled: _enabled,
      autoOnStart: _autoOnStart,
      autoOnEdit: _autoOnEdit,
      wifiOnly: _wifiOnly,
      serverUrl: _serverUrl.text.trim(),
      username: _username.text.trim(),
      secret: _secret.text,
      bucket: _bucket.text.trim(),
      region: _emptyToNull(_region.text),
      prefix: _emptyToNull(_prefix.text),
    );
  }

  /// 保存校验：enabled 时 webdav 需 serverUrl，s3 需 endpoint + bucket 非空。
  bool get _hasRequiredConnection {
    final endpointFilled = _serverUrl.text.trim().isNotEmpty;
    if (_type == RemoteType.webdav) return endpointFilled;
    return endpointFilled && _bucket.text.trim().isNotEmpty;
  }

  // ─────────────────────────── 操作 ───────────────────────────

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_enabled && !_hasRequiredConnection) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.syncConfigIncomplete)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await saveSyncConfig(ref, _buildConfig());
      ref.invalidate(syncConfigProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.syncCredsSaved)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.syncSaveFail)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!_hasRequiredConnection) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.syncConfigIncomplete)),
      );
      return;
    }
    setState(() => _testing = true);
    final result = await testSyncConnection(ref, _buildConfig());
    if (!mounted) return;
    setState(() => _testing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.ok ? l10n.syncTestOk : _syncErrorText(l10n, result.errorCode),
        ),
      ),
    );
  }

  Future<void> _syncNow() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!_hasRequiredConnection) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.syncConfigIncomplete)),
      );
      return;
    }

    if (!_enabled) {
      setState(() => _enabled = true);
    }
    setState(() => _saving = true);
    try {
      await saveSyncConfig(ref, _buildConfig());
      ref.invalidate(syncConfigProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.syncSaveFail)));
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    final triggers = ref.read(syncTriggersProvider);
    final result = await triggers.runNow();
    if (!mounted) return;

    if (result.ok) {
      setState(() => _lastErrorRetryable = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.syncStatusSuccess)));
      return;
    }
    if (result.skipped) {
      setState(() => _lastErrorRetryable = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.syncNotConfigured)));
      return;
    }

    setState(() => _lastErrorRetryable = result.retryable);
    messenger.showSnackBar(
      SnackBar(content: Text(_syncErrorText(l10n, result.errorCode))),
    );
    if (result.retryable) {
      unawaited(triggers.scheduleRetryIfNeeded(result));
    }
  }

  // ─────────────────────────── UI ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(syncConfigProvider);
    final syncState = ref.watch(syncStateProvider);

    if (!_loaded) {
      final config = configAsync.value;
      if (config != null) {
        _loaded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyConfig(config);
        });
      }
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isWide = AppBreakpoints.isWide(context);

    final body = ListView(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      children: [
        _buildStatusCard(l10n, theme, syncState, configAsync),
        const SizedBox(height: AppTokens.spaceLg),
        _SettingsCard(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.syncEnabled, style: theme.textTheme.bodyLarge),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.syncType, style: theme.textTheme.bodyLarge),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                child: ModernSegmentedControl<RemoteType>(
                  selectedValue: _type,
                  indicatorColor: theme.colorScheme.primary,
                  selectedTextColor: theme.colorScheme.onPrimary,
                  onChanged: (type) => unawaited(_onTypeChanged(type)),
                  items: [
                    ModernSegmentItem(
                      value: RemoteType.webdav,
                      label: l10n.syncTypeNutstore,
                      icon: Icons.cloud_outlined,
                    ),
                    ModernSegmentItem(
                      value: RemoteType.s3,
                      label: l10n.syncTypeS3,
                      icon: Icons.storage_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceLg),
        _SettingsCard(
          children: [
            TextField(
              controller: _serverUrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: _type == RemoteType.webdav
                    ? l10n.syncServerUrl
                    : l10n.syncEndpoint,
                hintText: _type == RemoteType.webdav
                    ? l10n.syncServerUrlHint
                    : l10n.syncEndpointHint,
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            TextField(
              controller: _username,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: _type == RemoteType.webdav
                    ? l10n.syncUsername
                    : l10n.syncAccessKey,
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            TextField(
              controller: _secret,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: _type == RemoteType.webdav
                    ? l10n.syncPassword
                    : l10n.syncSecretKey,
                helperText: _type == RemoteType.webdav
                    ? l10n.syncWebdavPasswordHint
                    : null,
              ),
            ),
            if (_type == RemoteType.s3) ...[
              const SizedBox(height: AppTokens.spaceMd),
              TextField(
                controller: _bucket,
                decoration: InputDecoration(labelText: l10n.syncBucket),
              ),
              const SizedBox(height: AppTokens.spaceMd),
              TextField(
                controller: _region,
                decoration: InputDecoration(
                  labelText: l10n.syncRegion,
                  hintText: l10n.syncRegionHint,
                ),
              ),
              const SizedBox(height: AppTokens.spaceMd),
              TextField(
                controller: _prefix,
                decoration: InputDecoration(
                  labelText: l10n.syncPrefix,
                  hintText: l10n.syncPrefixHint,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppTokens.spaceLg),
        _SettingsCard(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.syncAutoOnStart),
              value: _autoOnStart,
              onChanged: (value) => setState(() => _autoOnStart = value),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.syncAutoOnEdit),
              value: _autoOnEdit,
              onChanged: (value) => setState(() => _autoOnEdit = value),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.syncWifiOnly),
              subtitle: Text(l10n.syncWifiOnlyHint),
              value: _wifiOnly,
              onChanged: (value) => setState(() => _wifiOnly = value),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceLg),
        _SettingsCard(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const _ButtonSpinner()
                        : const Icon(Icons.wifi_tethering_outlined),
                    label: Text(l10n.syncTestConnection),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (syncState.status == SyncStateStatus.syncing || _saving)
                        ? null
                        : _syncNow,
                    icon: syncState.status == SyncStateStatus.syncing
                        ? const _ButtonSpinner()
                        : const Icon(Icons.sync),
                    label: Text(l10n.syncNow),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const _ButtonSpinner()
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.syncSave),
              ),
            ),
          ],
        ),
      ],
    );

    return isWide
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
              child: body,
            ),
          )
        : body;
  }

  /// 状态展示区：订阅 syncStateProvider。
  Widget _buildStatusCard(
    AppLocalizations l10n,
    ThemeData theme,
    SyncState state,
    AsyncValue<SyncConfig> configAsync,
  ) {
    final colorScheme = theme.colorScheme;
    final lastSynced = state.lastSyncedAt ?? configAsync.value?.lastSyncedAt;

    final (icon, title) = switch (state.status) {
      SyncStateStatus.syncing => (
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        l10n.syncStatusSyncing,
      ),
      SyncStateStatus.success => (
        Icon(Icons.check_circle, color: AppTokens.colorDone, size: 24),
        l10n.syncStatusSuccess,
      ),
      SyncStateStatus.error => (
        Icon(Icons.error_outline, color: colorScheme.error, size: 24),
        l10n.syncStatusError,
      ),
      SyncStateStatus.idle => (
        Icon(
          Icons.cloud_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
        lastSynced != null ? l10n.syncStatusSuccess : l10n.syncStatusIdle,
      ),
    };

    final String subtitle = switch (state.status) {
      SyncStateStatus.error => _syncErrorText(l10n, state.errorCode),
      _ when lastSynced != null => l10n.syncLastSyncedAt(
        formatDateTime(lastSynced),
      ),
      _ => l10n.syncNotConfigured,
    };

    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark
            ? AppTokens.cardShadowDarkList
            : AppTokens.cardShadowLight,
      ),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      child: Row(
        children: [
          ExcludeSemantics(child: icon),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppTokens.spaceXxs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: state.status == SyncStateStatus.error
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_lastErrorRetryable &&
                    state.status == SyncStateStatus.error) ...[
                  const SizedBox(height: AppTokens.spaceXxs),
                  Text(
                    l10n.syncRetryable,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 按钮内小号 spinner。
class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _syncErrorText(AppLocalizations l10n, SyncErrorCode? errorCode) {
  return switch (errorCode) {
    SyncErrorCode.skippedRunning => l10n.syncErrSkippedRunning,
    SyncErrorCode.clockSkew => l10n.syncErrClockSkew,
    SyncErrorCode.auth => l10n.syncErrAuth,
    SyncErrorCode.network => l10n.syncErrNetwork,
    SyncErrorCode.remote => l10n.syncErrRemote,
    SyncErrorCode.config => l10n.syncErrConfig,
    SyncErrorCode.schemaMismatch => l10n.syncErrSchemaMismatch,
    SyncErrorCode.snapshotCorrupt => l10n.syncErrSnapshotCorrupt,
    SyncErrorCode.unknown => l10n.syncErrUnknown,
    null => l10n.syncStatusError,
  };
}

/// 设置分组卡片
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        boxShadow: isDark
            ? AppTokens.cardShadowDarkList
            : AppTokens.cardShadowLight,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
          side: BorderSide(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Column(children: children),
        ),
      ),
    );
  }
}
