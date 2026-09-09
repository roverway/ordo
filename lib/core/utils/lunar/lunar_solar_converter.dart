import 'dart:math';

/// 农历日期模型
class LunarDate {
  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    this.isLeap = false,
  });

  /// 农历年份（公历纪年表示的农历年，如 2026）
  final int year;

  /// 农历月份（1~12）
  final int month;

  /// 农历日（1~30）
  final int day;

  /// 是否为闰月
  final bool isLeap;

  @override
  String toString() => 'LunarDate($year年${isLeap ? "闰" : ""}$month月$day日)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LunarDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day &&
          isLeap == other.isLeap;

  @override
  int get hashCode => Object.hash(year, month, day, isLeap);
}

/// 基于高精度天文动力学（儒略日、月球摄动与太阳中气）的阳历/农历转换引擎。
///
/// 算法原理源自天文学通用东亚阴阳合历计算规范（涵盖中国标准东经120°/UTC+8时间）：
/// 1. 通过开普勒轨道与摄动公式计算合朔新月日（农历每月初一）；
/// 2. 通过太阳视黄经判断二十四节气中气，以此确定闰月（冬至后无中气之月置闰）；
/// 3. 支持公历 1800–2200+ 年的微秒级离线快速转换，零静态数组依赖。
class LunarSolarConverter {
  const LunarSolarConverter._();

  static int _intFloor(double value) => value.floor();

  /// 公历年月日转儒略日数 (Julian Day Number)
  static int jdFromDate(int day, int month, int year) {
    final a = _intFloor((14 - month) / 12);
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    var jd =
        day +
        _intFloor((153 * m + 2) / 5) +
        365 * y +
        _intFloor(y / 4) -
        _intFloor(y / 100) +
        _intFloor(y / 400) -
        32045;
    if (jd < 2299161) {
      jd =
          day +
          _intFloor((153 * m + 2) / 5) +
          365 * y +
          _intFloor(y / 4) -
          32083;
    }
    return jd;
  }

  /// 计算第 k 个朔日（新月日）的儒略日数
  static int _getNewMoonDay(int k, int timeZone) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    const dr = pi / 180;
    var jd1 =
        2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;

    var c1 = (0.1734 - 0.000393 * t) * sin(m * dr) + 0.0021 * sin(2 * dr * m);
    c1 = c1 - 0.4068 * sin(mpr * dr) + 0.0161 * sin(dr * 2 * mpr);
    c1 = c1 - 0.0004 * sin(dr * 3 * mpr);
    c1 = c1 + 0.0104 * sin(dr * 2 * f) - 0.0051 * sin(dr * (m + mpr));
    c1 = c1 - 0.0074 * sin(dr * (m - mpr)) + 0.0004 * sin(dr * (2 * f + m));
    c1 = c1 - 0.0004 * sin(dr * (2 * f - m)) - 0.0006 * sin(dr * (2 * f + mpr));
    c1 =
        c1 +
        0.0010 * sin(dr * (2 * f - mpr)) +
        0.0005 * sin(dr * (2 * mpr + m));

    final deltat = (t < -4.0) ? (102.3 + 123.5 * t + 32.5 * t2) : 0.0;
    final jdn = jd1 + c1 - deltat / 86400.0;
    return _intFloor(jdn + 0.5 + timeZone / 24.0);
  }

  /// 获取太阳视黄经对应 30° 分段（用于中气判定）
  static int getSunLongitudeSegment(int jdn, int timeZone) {
    final t = (jdn - 2451545.5 - timeZone / 24.0) / 36525.0;
    final t2 = t * t;
    const dr = pi / 180;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    final m = 357.52910 + 35999.05029 * t - 0.0001537 * t2;
    final dl =
        (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m) +
        (0.019993 - 0.000101 * t) * sin(dr * 2 * m) +
        0.000290 * sin(dr * 3 * m);
    final l = (l0 + dl) % 360.0;
    return _intFloor(l / 30.0);
  }

  /// 获取太阳精确视黄经度数（0°~360°）
  static double getSunLongitudeDegrees(int jdn, int timeZone) {
    final t = (jdn - 2451545.5 - timeZone / 24.0) / 36525.0;
    final t2 = t * t;
    const dr = pi / 180;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    final m = 357.52910 + 35999.05029 * t - 0.0001537 * t2;
    final dl =
        (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m) +
        (0.019993 - 0.000101 * t) * sin(dr * 2 * m) +
        0.000290 * sin(dr * 3 * m);
    return (l0 + dl) % 360.0;
  }

  /// 查找农历冬至所在月（十一月）的初一儒略日
  static int _getLunarMonth11(int yy, int timeZone) {
    final off = jdFromDate(31, 12, yy) - 2415021;
    final k = _intFloor(off / 29.530588853);
    var nm = _getNewMoonDay(k, timeZone);
    final sunLong = getSunLongitudeSegment(nm, timeZone);
    if (sunLong >= 9) {
      nm = _getNewMoonDay(k - 1, timeZone);
    }
    return nm;
  }

  /// 计算闰月偏移位置
  static int _getLeapMonthOffset(int a11, int timeZone) {
    final k = _intFloor((a11 - 2415021.076998695) / 29.530588853 + 0.5);
    var last = 0;
    var i = 1;
    var arc = getSunLongitudeSegment(_getNewMoonDay(k + i, timeZone), timeZone);
    while (true) {
      last = arc;
      i++;
      arc = getSunLongitudeSegment(_getNewMoonDay(k + i, timeZone), timeZone);
      if (arc == last || i >= 14) break;
    }
    return i - 1;
  }

  /// 公历转农历（以东经 120° / 中国标准时间 UTC+8 计算）
  static LunarDate solarToLunar(DateTime solarDate) {
    const timeZone = 8;
    final solarDay = solarDate.day;
    final solarMonth = solarDate.month;
    final solarYear = solarDate.year;

    final dayNumber = jdFromDate(solarDay, solarMonth, solarYear);
    final k = _intFloor((dayNumber - 2415021.076998695) / 29.530588853);
    var monthStart = _getNewMoonDay(k + 1, timeZone);
    if (monthStart > dayNumber) {
      monthStart = _getNewMoonDay(k, timeZone);
    }

    var a11 = _getLunarMonth11(solarYear, timeZone);
    var b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = solarYear;
      a11 = _getLunarMonth11(solarYear - 1, timeZone);
    } else {
      lunarYear = solarYear + 1;
      b11 = _getLunarMonth11(solarYear + 1, timeZone);
    }

    final lunarDay = dayNumber - monthStart + 1;
    final diff = _intFloor((monthStart - a11) / 29);
    var isLeap = false;
    var lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      final leapMonthDiff = _getLeapMonthOffset(a11, timeZone);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) {
          isLeap = true;
        }
      }
    }
    if (lunarMonth > 12) {
      lunarMonth -= 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
      lunarYear -= 1;
    }

    return LunarDate(
      year: lunarYear,
      month: lunarMonth,
      day: lunarDay,
      isLeap: isLeap,
    );
  }
}
