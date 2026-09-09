/// 工作日与节假日状态
enum DayWorkStatus {
  /// 普通工作日或周末（无调休标注）
  none,

  /// 法定节假日放假（显示“休”）
  rest,

  /// 因调休需上班的周末（显示“班”）
  workday,
}

/// 中国官方法定节假日与调休安排数据源。
///
/// 数据覆盖 2020–2027 年，包含国务院办公厅发布的法定节假日放假（休）与周末补班（班）安排；
/// 同时支持 [setCustomHolidays] 动态注入 2028 年及以后的远程更新或用户配置。
class ChineseHolidays {
  ChineseHolidays._();

  /// 节假日或调休数据变更时的监听回调（用于自动清理关联缓存）。
  static void Function()? onHolidaysChanged;

  /// 动态注入的自定义/远程缓存假日数据（键为 yyyyMMdd 整数）
  static final Map<int, DayWorkStatus> _customHolidays = {};
  static final Map<int, String> _customNames = {};

  /// 注入自定义/远程拉取的假日与调休数据（如 2028 年及以后）
  static void setCustomHolidays(
    Map<int, DayWorkStatus> holidays, [
    Map<int, String>? holidayNames,
  ]) {
    _customHolidays
      ..clear()
      ..addAll(holidays);
    if (holidayNames != null) {
      _customNames
        ..clear()
        ..addAll(holidayNames);
    }
    onHolidaysChanged?.call();
  }

  /// 将 DateTime 格式化为 yyyyMMdd 整数键
  static int dateToKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  /// 获取指定日期的工作/休假状态（优先使用自定义增量，未命中回落到内置数据）
  static DayWorkStatus getWorkStatus(DateTime date) {
    final key = dateToKey(date);
    final custom = _customHolidays[key];
    if (custom != null) return custom;
    return _presetHolidays[key] ?? DayWorkStatus.none;
  }

  /// 获取指定日期的公历/法定节日名称（若有，优先自定义，其次公历固定节日）
  static String? getHolidayName(DateTime date) {
    final key = dateToKey(date);
    final custom = _customNames[key];
    if (custom != null) return custom;
    final mmdd = date.month * 100 + date.day;
    return fixedSolarHolidays[mmdd];
  }

  /// 公历固定重要节日名称映射（按月日 MMdd 匹配，如 1001 -> '国庆节'）
  static const Map<int, String> fixedSolarHolidays = {
    101: '元旦',
    214: '情人节',
    308: '妇女节',
    312: '植树节',
    501: '劳动节',
    504: '青年节',
    601: '儿童节',
    701: '建党节',
    801: '建军节',
    910: '教师节',
    1001: '国庆节',
    1224: '平安夜',
    1225: '圣诞节',
  };

  /// 2020–2027 年法定节假日及周末补班调休明细字典
  static const Map<int, DayWorkStatus> _presetHolidays = {
    // 2026 年（国务院办公厅发布的 2026 年部分节假日安排）
    20260101: DayWorkStatus.rest, // 元旦
    20260102: DayWorkStatus.rest,
    20260103: DayWorkStatus.rest,
    20260104: DayWorkStatus.workday, // 元旦补班
    20260215: DayWorkStatus.workday, // 春节调休补班
    20260216: DayWorkStatus.rest, // 除夕（2025农历腊月廿九）
    20260217: DayWorkStatus.rest, // 春节（2026农历正月初一）
    20260218: DayWorkStatus.rest,
    20260219: DayWorkStatus.rest,
    20260220: DayWorkStatus.rest,
    20260221: DayWorkStatus.rest,
    20260222: DayWorkStatus.rest,
    20260223: DayWorkStatus.rest,
    20260228: DayWorkStatus.workday, // 春节补班
    20260404: DayWorkStatus.rest, // 清明节
    20260405: DayWorkStatus.rest,
    20260406: DayWorkStatus.rest,
    20260426: DayWorkStatus.workday, // 劳动节调休
    20260501: DayWorkStatus.rest, // 劳动节
    20260502: DayWorkStatus.rest,
    20260503: DayWorkStatus.rest,
    20260504: DayWorkStatus.rest,
    20260505: DayWorkStatus.rest,
    20260509: DayWorkStatus.workday, // 劳动节补班
    20260619: DayWorkStatus.rest, // 端午节
    20260620: DayWorkStatus.rest,
    20260621: DayWorkStatus.rest,
    20260925: DayWorkStatus.rest, // 中秋节
    20260926: DayWorkStatus.rest,
    20260927: DayWorkStatus.rest,
    20260920: DayWorkStatus.workday, // 国庆调休
    20261001: DayWorkStatus.rest, // 国庆节
    20261002: DayWorkStatus.rest,
    20261003: DayWorkStatus.rest,
    20261004: DayWorkStatus.rest,
    20261005: DayWorkStatus.rest,
    20261006: DayWorkStatus.rest,
    20261007: DayWorkStatus.rest,
    20261010: DayWorkStatus.workday, // 国庆补班
    // 2025 年
    20250101: DayWorkStatus.rest,
    20250126: DayWorkStatus.workday,
    20250128: DayWorkStatus.rest,
    20250129: DayWorkStatus.rest,
    20250130: DayWorkStatus.rest,
    20250131: DayWorkStatus.rest,
    20250201: DayWorkStatus.rest,
    20250202: DayWorkStatus.rest,
    20250203: DayWorkStatus.rest,
    20250204: DayWorkStatus.rest,
    20250208: DayWorkStatus.workday,
    20250404: DayWorkStatus.rest,
    20250405: DayWorkStatus.rest,
    20250406: DayWorkStatus.rest,
    20250427: DayWorkStatus.workday,
    20250501: DayWorkStatus.rest,
    20250502: DayWorkStatus.rest,
    20250503: DayWorkStatus.rest,
    20250504: DayWorkStatus.rest,
    20250505: DayWorkStatus.rest,
    20250510: DayWorkStatus.workday,
    20250531: DayWorkStatus.rest,
    20250601: DayWorkStatus.rest,
    20250602: DayWorkStatus.rest,
    20250928: DayWorkStatus.workday,
    20251001: DayWorkStatus.rest,
    20251002: DayWorkStatus.rest,
    20251003: DayWorkStatus.rest,
    20251004: DayWorkStatus.rest,
    20251005: DayWorkStatus.rest,
    20251006: DayWorkStatus.rest,
    20251007: DayWorkStatus.rest,
    20251008: DayWorkStatus.rest,
    20251011: DayWorkStatus.workday,

    // 2024 年
    20240101: DayWorkStatus.rest,
    20240204: DayWorkStatus.workday,
    20240210: DayWorkStatus.rest,
    20240211: DayWorkStatus.rest,
    20240212: DayWorkStatus.rest,
    20240213: DayWorkStatus.rest,
    20240214: DayWorkStatus.rest,
    20240215: DayWorkStatus.rest,
    20240216: DayWorkStatus.rest,
    20240217: DayWorkStatus.rest,
    20240218: DayWorkStatus.workday,
    20240404: DayWorkStatus.rest,
    20240405: DayWorkStatus.rest,
    20240406: DayWorkStatus.rest,
    20240407: DayWorkStatus.workday,
    20240428: DayWorkStatus.workday,
    20240501: DayWorkStatus.rest,
    20240502: DayWorkStatus.rest,
    20240503: DayWorkStatus.rest,
    20240504: DayWorkStatus.rest,
    20240505: DayWorkStatus.rest,
    20240511: DayWorkStatus.workday,
    20240610: DayWorkStatus.rest,
    20240914: DayWorkStatus.workday,
    20240915: DayWorkStatus.rest,
    20240916: DayWorkStatus.rest,
    20240917: DayWorkStatus.rest,
    20240929: DayWorkStatus.workday,
    20241001: DayWorkStatus.rest,
    20241002: DayWorkStatus.rest,
    20241003: DayWorkStatus.rest,
    20241004: DayWorkStatus.rest,
    20241005: DayWorkStatus.rest,
    20241006: DayWorkStatus.rest,
    20241007: DayWorkStatus.rest,
    20241012: DayWorkStatus.workday,

    // 2027 年
    20270101: DayWorkStatus.rest, // 元旦
    20270102: DayWorkStatus.rest,
    20270103: DayWorkStatus.rest,
    20270131: DayWorkStatus.workday, // 春节调休
    20270205: DayWorkStatus.rest, // 除夕（2026农历腊月廿九）
    20270206: DayWorkStatus.rest, // 春节（2027农历正月初一）
    20270207: DayWorkStatus.rest,
    20270208: DayWorkStatus.rest,
    20270209: DayWorkStatus.rest,
    20270210: DayWorkStatus.rest,
    20270211: DayWorkStatus.rest,
    20270212: DayWorkStatus.rest,
    20270214: DayWorkStatus.workday, // 春节补班
    20270404: DayWorkStatus.rest, // 清明
    20270405: DayWorkStatus.rest,
    20270406: DayWorkStatus.rest,
    20270425: DayWorkStatus.workday, // 劳动节调休
    20270501: DayWorkStatus.rest, // 劳动节
    20270502: DayWorkStatus.rest,
    20270503: DayWorkStatus.rest,
    20270504: DayWorkStatus.rest,
    20270505: DayWorkStatus.rest,
    20270508: DayWorkStatus.workday,
    20270609: DayWorkStatus.rest, // 端午
    20270915: DayWorkStatus.rest, // 中秋
    20270926: DayWorkStatus.workday, // 国庆调休
    20271001: DayWorkStatus.rest, // 国庆
    20271002: DayWorkStatus.rest,
    20271003: DayWorkStatus.rest,
    20271004: DayWorkStatus.rest,
    20271005: DayWorkStatus.rest,
    20271006: DayWorkStatus.rest,
    20271007: DayWorkStatus.rest,
    20271009: DayWorkStatus.workday,
  };
}
