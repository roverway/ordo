import 'lunar_data.dart';
import 'lunar_solar_converter.dart';

/// 二十四节气计算工具
class SolarTermsCalculator {
  const SolarTermsCalculator._();

  /// 检查指定公历日期 [date] 是否为二十四节气之一。
  ///
  /// 若是，返回节气名称（如 "立春", "春分", "清明", "冬至" 等），否则返回 null。
  static String? getSolarTerm(DateTime date) {
    const timeZone = 8;
    final jdnToday = LunarSolarConverter.jdFromDate(
      date.day,
      date.month,
      date.year,
    );
    // 当日 00:00 与次日 00:00 的视黄经（即当日全天 24 小时跨度）
    final degStart = LunarSolarConverter.getSunLongitudeDegrees(
      jdnToday,
      timeZone,
    );
    final degEnd = LunarSolarConverter.getSunLongitudeDegrees(
      jdnToday + 1,
      timeZone,
    );

    final startIndex = (degStart / 15.0).floor();
    var endIndex = (degEnd / 15.0).floor();

    // 处理 360° 回绕（从双鱼座回到白羊座 0° 春分点）
    if (degStart > 350.0 && degEnd < 10.0) {
      endIndex += 24;
    }

    if (endIndex > startIndex) {
      final termIndex = endIndex % 24;
      if (termIndex >= 0 && termIndex < LunarData.solarTerms.length) {
        return LunarData.solarTerms[termIndex];
      }
    }
    return null;
  }
}
