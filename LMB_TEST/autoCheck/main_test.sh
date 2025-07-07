#!/bin/bash
# filepath: main_test.sh

HW_TEST_DIR="/usr/local/bin/hw_test"
LOG_DIR="/tmp/hw_test_logs"
REPORT_FILE="/tmp/hw_test_report.txt"

echo "========================================"
echo "RK3588 硬件功能全面测试 - $(date)"
echo "========================================"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 测试项目列表
TESTS=(
    "wifi:WiFi功能"
    "bt:蓝牙功能"  
    "eth:以太网功能"
    "usb:USB功能"
    "audio:音频功能"
    "gpio:GPIO功能"
    "pcie:PCIe功能"
)

# 测试结果统计
PASSED=0
FAILED=0
TOTAL=${#TESTS[@]}

# 清空报告文件
> "$REPORT_FILE"

echo "开始硬件功能测试..."
echo "===================="

for test_item in "${TESTS[@]}"; do
    IFS=':' read -r test_name test_desc <<< "$test_item"
    
    echo ""
    echo "[$((PASSED + FAILED + 1))/$TOTAL] 测试 $test_desc..."
    echo "----------------------------------------"
    
    # 执行具体测试脚本
    if [ -f "$HW_TEST_DIR/${test_name}_test.sh" ]; then
        if timeout 30 "$HW_TEST_DIR/${test_name}_test.sh" > "$LOG_DIR/${test_name}_test.log" 2>&1; then
            # 检查测试结果（根据特定关键词判断）
            if grep -q "测试成功\|功能正常\|OK" "$LOG_DIR/${test_name}_test.log"; then
                echo "✅ $test_desc: 通过"
                echo "✅ $test_desc: 通过" >> "$REPORT_FILE"
                ((PASSED++))
            else
                echo "❌ $test_desc: 失败"
                echo "❌ $test_desc: 失败" >> "$REPORT_FILE"
                # 提取关键错误信息
                grep -E "(error|fail|timeout|not found)" "$LOG_DIR/${test_name}_test.log" | head -3 >> "$REPORT_FILE"
                ((FAILED++))
            fi
        else
            echo "❌ $test_desc: 脚本执行失败或超时"
            echo "❌ $test_desc: 脚本执行失败或超时" >> "$REPORT_FILE"
            ((FAILED++))
        fi
    else
        echo "⚠️  $test_desc: 测试脚本不存在"
        echo "⚠️  $test_desc: 测试脚本不存在" >> "$REPORT_FILE"
        ((FAILED++))
    fi
done

echo ""
echo "========================================"
echo "测试总结"
echo "========================================"
echo "总计: $TOTAL 项"
echo "通过: $PASSED 项"
echo "失败: $FAILED 项"
echo "成功率: $(( PASSED * 100 / TOTAL ))%"

# 显示详细报告
echo ""
echo "详细报告:"
echo "----------------------------------------"
cat "$REPORT_FILE"

echo ""
echo "详细日志保存在: $LOG_DIR/"
echo "完整报告保存在: $REPORT_FILE"

# 如果有失败项，返回非零退出码
[ $FAILED -eq 0 ]