/// 业务数据变更观察者接口（依赖倒置解耦）。
///
/// 当底层 TodoRepository 发生写操作时通知上层，
/// 上层可实现该接口接入自动同步防抖触发（SyncTriggers）或备份快照等，
/// 避免底层直接依赖上层同步模块或依赖 main.dart 裸函数手动赋值。
abstract interface class DataChangeObserver {
  /// 当数据发生变更时调用。
  Future<void> onDataChanged();
}
