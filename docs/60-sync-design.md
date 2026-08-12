# 60 — 同步设计（Sync Design）

> 定义接力同步协议：快照格式、合并算法、首次同步、并发控制、墓碑清理、RemoteStore 接口与错误处理。**这是本项目最核心、最易出错的部分，实现前必须通读。**

## 1. 目标与非目标

**目标**：个人多设备间可靠接力同步（同一时刻仅一台设备编辑），数据不丢失、可调试、天然备份。

**非目标**：多端同时编辑、实时协作、冲突 UI 解决、多人共享。

**适用规模**：<5 万条记录，单快照压缩后几十 MB 内可接受。

## 2. 总体方案

- **单文件快照**：所有数据序列化为一个 JSON 快照，gzip 压缩后整体上传/下载（原子替换）。
- **按记录 LWW 合并**：每条记录带 `id / updatedAt / deleted`，合并时同 id 取 `updatedAt` 较大者。
- **墓碑**：删除 = 本地硬删 + 快照中保留 `deleted=true` 墓碑，向其他设备传播删除。
- **双远端实现**：WebDAV 与 S3 兼容桶，统一 `RemoteStore` 抽象。

## 3. 快照格式（schemaVersion = 1）

远端对象键（默认）：`todo/data.json.gz`（前缀可配置）。

```json
{
  "schemaVersion": 1,
  "deviceId": "uuid-of-this-device",
  "exportedAt": 1720000000000,
  "projects": [
    { "id": "uuid", "name": "工作", "color": 4283215696,
      "sortOrder": 0, "createdAt": 1720000000000, "updatedAt": 1720000000000, "deleted": false }
  ],
  "tasks": [
    { "id": "uuid", "projectId": "uuid", "parentId": null,
      "title": "写周报", "description": "", "notes": "",
      "startAt": null, "endAt": 1720500000000,
      "status": 0, "priority": 2, "sortOrder": 0,
      "createdAt": 1720000000000, "updatedAt": 1720000000000, "deleted": false,
      "tagIds": ["tag-uuid-1"] }
  ],
  "tags": [
    { "id": "uuid", "name": "重要", "color": 4283215696,
      "sortOrder": 0, "createdAt": 1720000000000, "updatedAt": 1720000000000, "deleted": false }
  ]
}
```

- 时间一律 UTC 毫秒整数；`deleted` 为布尔。
- **tagIds 内嵌于 task 记录**：使「任务 + 标签关联」作为一条记录原子合并，避免联表冲突。
- 快照不含 settings（设备本地）与凭据（安全存储）。

## 4. 合并算法（MergeEngine，纯函数）

```
merge(local, remote):
  for type in [projects, tasks, tags]:
    map = {}
    for row in local[type]:  map[row.id] = row
    for row in remote[type]:
      if map contains row.id:
        if row.updatedAt > map[row.id].updatedAt:  map[row.id] = row
        else if row.updatedAt == map[row.id].updatedAt:
          map[row.id] = tieBreak(map[row.id], row, local.deviceId, remote.deviceId)
      else:
        map[row.id] = row
    result[type] = map.values
  result = reconcileTagIds(result)   # §7
  return result
```

- **tie-break**：`updatedAt` 相同时，比较 `(deviceId, id)` 字典序，取大者（确定性，避免两端不一致）。
- **应用规则**：合并结果中 `deleted=true` 的记录 → 从本地 DB 硬删（墓碑保留在快照）；其余 → upsert 到 DB。
- **边界**：一端删除（墓碑 updatedAt 新）vs 另一端修改 → 墓碑胜，修改丢失（LWW 语义，文档明示）；用户可接受（个人接力场景）。

## 5. 首次同步四分支（FR-SYNC-03）

| 本地 | 远端 | 行为 |
|---|---|---|
| 空 | 有 | 下载 → 合并（本地无冲突）→ 应用 |
| 有 | 空 | 上传本地快照 |
| 有 | 有 | 下载 → 合并 → 应用 → 重新导出上传 |
| — | schemaVersion 不匹配 | **拒绝**并警告「请升级应用」 |

## 6. 并发控制（防重入 + 读改写）

- **串行队列**：同一时刻只允许一个同步任务（`SyncEngine` 内部互斥），防重入。
- **读-改-写**：`download → merge → upload` 期间，若远端被其他设备修改（upload 前比对 `lastModified` 变化），则**重新 download + merge** 后再上传（最多重试 2 次）。
- 本地编辑与同步并发：同步应用合并结果在事务内完成；期间本地写入排队（DB 事务串行）。

## 7. 标签孤儿清理（reconciliation）

- 合并后：对每个 task 的 `tagIds`，删除指向「不存在或 `deleted=true`」的 tag 的引用。
- 目的：标签在 A 设备删除、任务在 B 设备保留时，不产生悬空引用。
- 实现：`reconcileTagIds(merged)` 纯函数，**必须单测**。

## 8. 墓碑清理

- 快照压缩（可选后台任务）时，清理 `deleted=true` 且 `updatedAt` 距今 >90 天的墓碑。
- 风险说明：清理后若旧设备重新同步，被清理的删除可能「复活」——个人接力场景可接受（文档明示）。
- 清理仅影响快照，不影响本地 DB。

## 9. RemoteStore 接口与实现

```dart
abstract class RemoteStore {
  Future<bool> exists();                    // 远端对象是否存在
  Future<Uint8List?> download();            // 下载（gzip 原始字节）
  Future<void> upload(Uint8List bytes);     // 上传（原子覆盖）
  Future<DateTime?> lastModified();         // 远端最后修改时间
}
```

### 9.1 WebDAV 实现（`remote_store_webdav.dart`）

- 依赖：`webdav_client`。
- 配置：`baseUrl`（如 `https://dav.example.com/todo/`）、`username`、`password`。
- 操作：`HEAD`（exists/lastModified）、`GET`（download）、`PUT`（upload）。
- 路径：`{baseUrl}{key}`，key 默认 `data.json.gz`。

### 9.2 S3 实现（`remote_store_s3.dart`）

- 依赖：`minio 3.5.8`（2026-08 选定；替代 `s3_dart`——其 `getRequestUrl` 会把自定义 endpoint 重写为 `s3.<region>.<endpoint>` 导致 R2/MinIO 不可用，见 `20-tech-stack.md` §4 备注）。
- 配置：`endpoint`（AWS/R2/MinIO/Wasabi 均可）、`region`（可选；R2 用 `auto`）、`bucket`、`prefix`（默认 `todo/`）、`accessKey`、`secretKey`。
- 操作：`statObject`（exists/lastModified，**必须传 `retrieveAcls: false`**——否则连带 `GET ?acl`，MinIO/R2 返回非标准 XML 抛 XmlParserException）、`getObject`（download）、`putObject`（upload）。
- 对象键：`{prefix}data.json.gz`。

### 9.3 工厂

- `RemoteStoreFactory.fromConfig(SyncConfig)`：按类型返回实现；配置无效抛领域异常。

## 10. 同步配置与触发

### 10.1 配置（SyncConfig）

| 项 | 存储 | 说明 |
|---|---|---|
| type（webdav/s3） | settings 表 | 非敏感 |
| enabled / autoOnStart / autoOnEdit / wifiOnly | settings 表 | 非敏感 |
| lastSyncedAt | settings 表 | 非敏感 |
| 服务器地址/账号/密钥 | **flutter_secure_storage** | 敏感，禁止日志 |

### 10.2 触发

| 触发 | 时机 |
|---|---|
| 手动 | 设置页「立即同步」按钮 |
| 启动自动 | App 启动后（可关） |
| 编辑自动 | 任何写操作后防抖 2s（可关） |
| WiFi-only | 仅 WiFi 时自动同步（Android 经 connectivity_plus 真实检测，M5 接入，2026-08；桌面恒真） |

### 10.3 上传优化（FR-SYNC-07）

- 上传前比对 `lastModified`/内容 hash，无变化跳过。
- 快照 gzip 压缩。
- 自动同步受 wifiOnly 约束。

## 11. 时钟偏差检测（FR-SYNC-06）

- 合并前：`|remote.exportedAt - now| > 5min` → 提示用户校准时钟（不静默合并，用户确认后继续）。
- 原因：LWW 依赖两端时钟；Windows 时钟漂移常见（Oracle 评审 H3）。

## 12. 错误处理（NFR-03）

| 场景 | 行为 |
|---|---|
| 网络失败/超时 | 不破坏本地库；`SyncState.error` 展示；指数退避重试（最多 5 次） |
| 认证失败 | 提示检查凭据；不重试 |
| schemaVersion 不匹配 | 拒绝同步并警告 |
| 快照损坏/解析失败 | 保留远端原文件；提示「远端数据异常」，不覆盖 |
| 上传失败 | 本地数据不变；下次触发重试 |

- 任何失败都不允许：清空本地库、覆盖远端好数据、丢失 lastSyncedAt。

## 13. 安全（FR-SYNC-05）

- 凭据仅存 `flutter_secure_storage`（Android Keystore / Windows DPAPI）。
- 日志禁止输出密钥/完整 URL（可输出 host）。
- 传输走 HTTPS（WebDAV/S3 endpoint 强制 https，测试环境除外）。

## 14. 测试场景清单（M4 DoD 依据）

| # | 场景 | 断言 |
|---|---|---|
| 1 | 本地新增 → 同步 | 远端快照含新记录 |
| 2 | 远端新增 → 同步 | 本地出现新记录 |
| 3 | 两端改同一 id | 取 updatedAt 大者 |
| 4 | 一端删除 | 墓碑传播，另一端删除 |
| 5 | 首次同步：本地空+远端有 | 下载 |
| 6 | 首次同步：本地有+远端空 | 上传 |
| 7 | schemaVersion 不匹配 | 拒绝 + 警告 |
| 8 | 标签删除后合并 | tagIds 悬空引用被清理 |
| 9 | 并发：上传前远端被改 | 重新下载合并后上传 |
| 10 | 快照损坏 | 不覆盖远端，报错可重试 |

- 单元测试：`merge_engine` / `reconcileTagIds` / `snapshot_codec`（纯函数）。
- 集成测试：`FakeRemoteStore` + 真实 MergeEngine + 内存 DB。
- 手工测试：真实 WebDAV（如坚果云/NAS）与 S3（如 R2/MinIO）各跑一遍场景 1–10。