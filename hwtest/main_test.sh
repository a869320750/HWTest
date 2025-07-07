#!/bin/bash
# filepath: hwtest

HW_TEST_DIR="/usr/local/bin/hw_test"
LOG_DIR="/tmp/hw_test_logs"
REPORT_FILE="/tmp/hw_test_report.txt"

TESTS=(
    "wifi:WiFi功能"
    "bt:蓝牙功能"  
    "eth:以太网功能"
    "usb:USB功能"
    "audio:音频功能"
    "gpio:GPIO功能"
    "pcie:PCIe功能"
)

usage() {
    echo "\n用法: hwtest [all|wifi|bt|eth|usb|audio|gpio|pcie|--help]"
    echo "----------------------------------------"
    echo "  all      : 全部功能一键检测"
    echo "  wifi     : 仅检测WiFi功能"
    echo "  bt       : 仅检测蓝牙功能"
    echo "  eth      : 仅检测以太网功能"
    echo "  usb      : 仅检测USB功能"
    echo "  audio    : 仅检测音频功能"
    echo "  gpio     : 仅检测GPIO功能"
    echo "  pcie     : 仅检测PCIe功能"
    echo "  --help   : 显示本帮助信息"
    echo "\n示例:"
    echo "  hwtest all      # 全部检测"
    echo "  hwtest wifi     # 只测WiFi"
    echo "  hwtest          # 显示帮助"
    exit 0
}

# 参数处理
if [[ $# -eq 0 || $1 == "--help" ]]; then
    usage
fi

# 创建日志目录
mkdir -p "$LOG_DIR"

run_test() {
    local test_name="$1"
    local test_desc="$2"
    echo "\n测试 $test_desc..."
    echo "----------------------------------------"
    if [ -f "$HW_TEST_DIR/${test_name}_test.sh" ]; then
        if timeout 30 "$HW_TEST_DIR/${test_name}_test.sh" > "$LOG_DIR/${test_name}_test.log" 2>&1; then
            if grep -q "测试成功\|功能正常\|OK" "$LOG_DIR/${test_name}_test.log"; then
                echo "✅ $test_desc: 通过"
                return 0
            else
                echo "❌ $test_desc: 失败"
                grep -E "(error|fail|timeout|not found)" "$LOG_DIR/${test_name}_test.log" | head -3
                return 1
            fi
        else
            echo "❌ $test_desc: 脚本执行失败或超时"
            return 1
        fi
    else
        echo "⚠️  $test_desc: 测试脚本不存在"
        return 1
    fi
}

if [[ $1 == "all" ]]; then
    echo "========================================"
    echo "RK3588 硬件功能全面测试 - $(date)"
    echo "========================================"
    PASSED=0
    FAILED=0
    TOTAL=${#TESTS[@]}
    > "$REPORT_FILE"
    for test_item in "${TESTS[@]}"; do
        IFS=':' read -r test_name test_desc <<< "$test_item"
        if run_test "$test_name" "$test_desc"; then
            echo "✅ $test_desc: 通过" >> "$REPORT_FILE"
            ((PASSED++))
        else
            echo "❌ $test_desc: 失败" >> "$REPORT_FILE"
            ((FAILED++))
        fi
    done
    echo "\n========================================"
    echo "测试总结"
    echo "========================================"
    echo "总计: $TOTAL 项"
    echo "通过: $PASSED 项"
    echo "失败: $FAILED 项"
    echo "成功率: $(( PASSED * 100 / TOTAL ))%"
    echo "\n详细报告:"
    echo "----------------------------------------"
    cat "$REPORT_FILE"
    echo "\n详细日志保存在: $LOG_DIR/"
    echo "完整报告保存在: $REPORT_FILE"
    [ $FAILED -eq 0 ]
    exit $?
else
    # 单项测试
    for test_item in "${TESTS[@]}"; do
        IFS=':' read -r test_name test_desc <<< "$test_item"
        if [[ $1 == "$test_name" ]]; then
            run_test "$test_name" "$test_desc"
            exit $?
        fi
    done
    echo "未知命令: $1"
    usage
fi