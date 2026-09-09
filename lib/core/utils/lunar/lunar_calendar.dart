import 'chinese_holidays.dart';
import 'lunar_data.dart';
import 'lunar_solar_converter.dart';
import 'solar_terms.dart';

/// 包含公历日期与对应农历、节气、法定假日的综合计算结果模型。
class LunarDayInfo {
  const LunarDayInfo({
    required this.solarDate,
    required this.lunarDate,
    required this.lunarMonthText,
    required this.lunarDayText,
    this.solarTerm,
    this.holidayName,
    this.traditionalFestival,
    this.workStatus = DayWorkStatus.none,
  });

  /// 公历日期
  final DateTime solarDate;

  /// 农历年月日模型
  final LunarDate lunarDate;

  /// 农历月份显示文本（如 "正月", "八月", "闰四月"）
  final String lunarMonthText;

  /// 农历日期显示文本（如 "初一", "十五", "廿八"）
  final String lunarDayText;

  /// 当日节气（如 "立春", "秋分"，无则为 null）
  final String? solarTerm;

  /// 法定假日/公历重要节日名（如 "元旦", "国庆节"，无则为 null）
  final String? holidayName;

  /// 传统民俗节日（如 "除夕", "春节", "端午节", "中秋节"，无则为 null）
  final String? traditionalFestival;

  /// 当日调休工作状态（none / rest / workday）
  final DayWorkStatus workStatus;

  /// 是否为节日或节气（用于日历格子文字高亮提示）
  bool get isSpecialDay =>
      holidayName != null ||
      traditionalFestival != null ||
      solarTerm != null ||
      lunarDate.day == 1;

  /// 日历方格内显示的简短副文本（通常不超过 4 个汉字）
  ///
  /// 优先级策略：
  /// 1. 法定假日/传统节日（如 "中秋", "国庆", "除夕", "元宵"）
  /// 2. 二十四节气（如 "秋分", "冬至"）
  /// 3. 农历每月初一（如 "八月", "闰四月"）
  /// 4. 普通农历日（如 "初八", "廿五"）
  String get displayText {
    // 1. 节日优先
    if (holidayName != null) {
      // 简化过长的名称以适应格子排版
      return _simplifyFestivalName(holidayName!);
    }
    if (traditionalFestival != null) {
      return _simplifyFestivalName(traditionalFestival!);
    }
    // 2. 二十四节气次之
    if (solarTerm != null) {
      return solarTerm!;
    }
    // 3. 初一显示月份
    if (lunarDate.day == 1) {
      return lunarMonthText;
    }
    // 4. 普通农历日
    return lunarDayText;
  }

  /// 议程列表或详情展示的完整农历与节日描述
  /// 例如: "农历八月十五 · 中秋节" 或 "农历七月廿七 · 白露"
  String get agendaDescription {
    final buffer = StringBuffer('农历$lunarMonthText$lunarDayText');
    final festival = holidayName ?? traditionalFestival;
    if (festival != null) {
      buffer.write(' · $festival');
    } else if (solarTerm != null) {
      buffer.write(' · $solarTerm');
    }
    return buffer.toString();
  }

  static String _simplifyFestivalName(String name) {
    if (name.endsWith('节') && name.length > 2) {
      return name.substring(0, name.length - 1);
    }
    return name;
  }
}

/// 统一农历与节假日查询门面
class LunarCalendar {
  const LunarCalendar._();

  /// 缓存最近查询，提升滑动性能
  static final Map<int, LunarDayInfo> _dayCache = {};
  static bool _hookInstalled = false;

  /// 清空农历日期信息缓存（当节假日数据动态更新或测试用例注入时调用）。
  static void clearCache() => _dayCache.clear();

  /// 获取指定公历日的农历与节假日信息
  static LunarDayInfo getDayInfo(DateTime solarDate) {
    if (!_hookInstalled) {
      _hookInstalled = true;
      ChineseHolidays.onHolidaysChanged = clearCache;
    }

    final key = ChineseHolidays.dateToKey(solarDate);
    final cached = _dayCache[key];
    if (cached != null) return cached;

    final lunar = LunarSolarConverter.solarToLunar(solarDate);

    // 农历月份与日期中文
    final rawMonth = (lunar.month >= 1 && lunar.month <= 12)
        ? LunarData.lunarMonths[lunar.month - 1]
        : '${lunar.month}月';
    final monthText = lunar.isLeap ? '闰$rawMonth' : rawMonth;

    final dayText = (lunar.day >= 1 && lunar.day <= 30)
        ? LunarData.lunarDays[lunar.day - 1]
        : '${lunar.day}日';

    // 二十四节气
    final term = SolarTermsCalculator.getSolarTerm(solarDate);

    // 法定节假日或公历重要节日
    String? holiday = ChineseHolidays.getHolidayName(solarDate);
    if (holiday == null) {
      final mmdd = solarDate.month * 100 + solarDate.day;
      holiday = ChineseHolidays.fixedSolarHolidays[mmdd];
    }

    // 传统农历节日
    final traditional = _findTraditionalFestival(solarDate, lunar);

    // 调休状态
    final status = ChineseHolidays.getWorkStatus(solarDate);

    final info = LunarDayInfo(
      solarDate: solarDate,
      lunarDate: lunar,
      lunarMonthText: monthText,
      lunarDayText: dayText,
      solarTerm: term,
      holidayName: holiday,
      traditionalFestival: traditional,
      workStatus: status,
    );

    // 限制缓存大小在 500 项内
    if (_dayCache.length > 500) {
      _dayCache.clear();
    }
    _dayCache[key] = info;
    return info;
  }

  /// 匹配传统农历民俗节日
  static String? _findTraditionalFestival(DateTime solarDate, LunarDate lunar) {
    // 除夕：明天是正月初一（采用基于日期的确定性构造，避免 Duration 夏令时偏差）
    final tomorrow = DateTime(
      solarDate.year,
      solarDate.month,
      solarDate.day + 1,
    );
    final tomorrowLunar = LunarSolarConverter.solarToLunar(tomorrow);
    if (tomorrowLunar.month == 1 && tomorrowLunar.day == 1) {
      return '除夕';
    }

    // 正月
    if (lunar.month == 1 && lunar.day == 1) return '春节';
    if (lunar.month == 1 && lunar.day == 15) return '元宵节';

    // 二月
    if (lunar.month == 2 && lunar.day == 2) return '龙抬头';

    // 五月
    if (lunar.month == 5 && lunar.day == 5) return '端午节';

    // 七月
    if (lunar.month == 7 && lunar.day == 7) return '七夕节';
    if (lunar.month == 7 && lunar.day == 15) return '中元节';

    // 八月
    if (lunar.month == 8 && lunar.day == 15) return '中秋节';

    // 九月
    if (lunar.month == 9 && lunar.day == 9) return '重阳节';

    // 腊月
    if (lunar.month == 12 && lunar.day == 8) return '腊八节';
    if (lunar.month == 12 && (lunar.day == 23 || lunar.day == 24)) return '小年';

    return null;
  }
}
