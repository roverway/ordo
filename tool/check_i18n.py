#!/usr/bin/env python3
"""
双语国际化一致性与完整性质量门禁 (Bilingual i18n Completeness Gate)

检查项：
1. ARB 键对称性：app_zh.arb 与 app_en.arb 必须 100% 双向对齐（零缺失键）。
2. ARB 翻译非空：双语键值均不可为空或仅包含空白字符。
3. ARB 占位符匹配：插值变量 {variable} 必须在中英文对等定义。
4. 英文 ARB 纯净度：app_en.arb 严禁混入中文字符（除原生名称白名单外）。
5. 核心 UI 模块零容忍：lib/features/tasks/widgets/task_editor/ 严禁出现任何硬编码中文字符串字面量（0 容忍）。
6. 全库 UI 模块硬编码中文棘轮守卫：lib/features/ 与 lib/shared/ 裸中文字符串总量只减不增（基线 116）。
"""

import json
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
os.chdir(REPO_ROOT)

ZH_PATTERN = re.compile(r'[\u4e00-\u9fa5]')
PLACEHOLDER_PATTERN = re.compile(r'\{([a-zA-Z0-9_]+)\}')
STRING_LITERAL_PATTERN = re.compile(r"(?:'([^'\\]*(?:\\.[^'\\]*)*)'|\"([^\"\\]*(?:\\.[^\"\\]*)*)\")")

EN_ZH_WHITELIST_KEYS = {
    'languageZh',          # 语言切换项原生中文名: "简体中文"
    'aboutBrandZhTitle',    # 关于页中文品牌名: "知序 (Zhī Xù)"
}

# UI 层裸中文字符串棘轮上限（只减不增）
MAX_UI_HARDCODED_ZH = 116

def check_arb_parity():
    zh_path = 'lib/core/l10n/app_zh.arb'
    en_path = 'lib/core/l10n/app_en.arb'

    if not os.path.exists(zh_path) or not os.path.exists(en_path):
        print(f"❌ ARB 文件缺失: {zh_path} 或 {en_path}")
        return False

    with open(zh_path, 'r', encoding='utf-8') as f:
        zh_data = json.load(f)
    with open(en_path, 'r', encoding='utf-8') as f:
        en_data = json.load(f)

    zh_keys = {k for k in zh_data if not k.startswith('@')}
    en_keys = {k for k in en_data if not k.startswith('@')}

    missing_in_en = zh_keys - en_keys
    missing_in_zh = en_keys - zh_keys

    errors = []
    if missing_in_en:
        errors.append(f"app_en.arb 缺失翻译键 ({len(missing_in_en)} 个): {sorted(missing_in_en)[:10]}")
    if missing_in_zh:
        errors.append(f"app_zh.arb 缺失模板键 ({len(missing_in_zh)} 个): {sorted(missing_in_zh)[:10]}")

    for k in zh_keys & en_keys:
        zh_val = str(zh_data[k])
        en_val = str(en_data[k])

        if not zh_val.strip():
            errors.append(f"app_zh.arb 键 [{k}] 翻译为空")
        if not en_val.strip():
            errors.append(f"app_en.arb 键 [{k}] 翻译为空")

        # 检查占位符
        zh_vars = set(PLACEHOLDER_PATTERN.findall(zh_val))
        en_vars = set(PLACEHOLDER_PATTERN.findall(en_val))
        if zh_vars != en_vars:
            errors.append(f"键 [{k}] 占位符不匹配: zh={zh_vars} vs en={en_vars}")

        # 检查英文 ARB 误填中文
        if k not in EN_ZH_WHITELIST_KEYS and ZH_PATTERN.search(en_val):
            errors.append(f"app_en.arb 键 [{k}] 包含中文字符: '{en_val}'")

    if errors:
        print(f"❌ ARB 双语一致性检查失败 (共 {len(errors)} 项违规):")
        for err in errors[:15]:
            print(f"   - {err}")
        if len(errors) > 15:
            print(f"   ... 其余 {len(errors) - 15} 项已截断")
        return False

    print(f"✅ ARB 双语对称与完整性通过：中英各 {len(zh_keys)} 个键 100% 对齐，占位符完全匹配，零空翻译。")
    return True

def check_ui_hardcoded_chinese():
    # 1. 核心模块零容忍检查 (task_editor / 日期时间选择器)
    zero_tolerance_dirs = ['lib/features/tasks/widgets/task_editor']
    zero_tolerance_violations = []

    for d in zero_tolerance_dirs:
        for root, _, files in os.walk(d):
            for f in files:
                if f.endswith('.dart'):
                    p = os.path.join(root, f)
                    with open(p, 'r', encoding='utf-8') as fp:
                        for idx, line in enumerate(fp, 1):
                            clean = re.sub(r'//.*$', '', line)
                            for m in STRING_LITERAL_PATTERN.finditer(clean):
                                s = m.group(1) if m.group(1) is not None else m.group(2)
                                if ZH_PATTERN.search(s):
                                    zero_tolerance_violations.append((p, idx, s))

    if zero_tolerance_violations:
        print(f"❌ 核心 UI 模块零容忍守卫失败！发现 {len(zero_tolerance_violations)} 处硬编码中文：")
        for p, idx, s in zero_tolerance_violations:
            print(f"   {p}:{idx}: '{s}'")
        print("   👉 必须使用 l10n 多语言资源（如 l10n.allDay 或 l10n.taskStartTime），严禁裸中文硬编码！")
        return False

    print("✅ 核心 UI 模块 (task_editor / 日期选择器) 零容忍守卫通过：0 处硬编码中文！")

    # 2. 全库 UI 模块硬编码中文棘轮守卫
    ui_dirs = ['lib/features', 'lib/shared']
    all_ui_violations = []

    for d in ui_dirs:
        for root, _, files in os.walk(d):
            for f in files:
                if f.endswith('.dart'):
                    p = os.path.join(root, f)
                    with open(p, 'r', encoding='utf-8') as fp:
                        for idx, line in enumerate(fp, 1):
                            clean = re.sub(r'//.*$', '', line)
                            for m in STRING_LITERAL_PATTERN.finditer(clean):
                                s = m.group(1) if m.group(1) is not None else m.group(2)
                                if ZH_PATTERN.search(s):
                                    all_ui_violations.append((p, idx, s))

    count = len(all_ui_violations)
    print(f"ℹ️  当前全库 UI 模块硬编码中文总数: {count}（棘轮上限基线: {MAX_UI_HARDCODED_ZH}）")

    if count > MAX_UI_HARDCODED_ZH:
        print(f"❌ [棘轮破窗] 全库 UI 模块硬编码中文字符串总数 ({count}) 超过基线上限 ({MAX_UI_HARDCODED_ZH})！")
        print("   新增 UI 业务逻辑必须走 l10n 国际化字典，严禁引入新的裸中文字符串。")
        return False

    print(f"✅ UI 模块双语硬编码棘轮守卫通过：当前 {count}/{MAX_UI_HARDCODED_ZH}，未发生破窗增长。")
    return True

def main():
    print("==========================================")
    print("🛡️  运行双语国际化完整性与硬编码门禁...")
    print("==========================================")

    arb_ok = check_arb_parity()
    ui_ok = check_ui_hardcoded_chinese()

    if not (arb_ok and ui_ok):
        sys.exit(1)

    print("🎉 双语国际化质量门禁全部通过！")

if __name__ == '__main__':
    main()
