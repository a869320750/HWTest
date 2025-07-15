#!/bin/bash
# GPIO功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/gpio_test.log

echo "开始GPIO功能测试..." | tee -a "$LOG"

# 检查GPIO相关接口和工具
check_gpio_support() {
    local result="成功"
    
    # 检查GPIO控制器设备
    local gpiochips=$(ls /dev/gpiochip* 2>/dev/null | wc -l)
    if [[ $gpiochips -gt 0 ]]; then
        echo "✓ 检测到 $gpiochips 个GPIO控制器" | tee -a "$LOG"
        ls /dev/gpiochip* 2>/dev/null | while read chip; do
            echo "  - $chip" | tee -a "$LOG"
        done
    else
        echo "✗ 未检测到GPIO控制器设备" | tee -a "$LOG"
        result="失败"
    fi
    
    # 检查pinctrl信息
    if [[ -d "/sys/kernel/debug/pinctrl" ]]; then
        echo "✓ 检测到pinctrl调试接口" | tee -a "$LOG"
    fi
    
    # 检查proc/gpio信息
    if [[ -r "/proc/gpio" ]]; then
        echo "✓ 检测到GPIO proc接口" | tee -a "$LOG"
    fi
    
    # 检查是否有libgpiod工具
    if command -v gpiodetect >/dev/null 2>&1; then
        echo "✓ 检测到libgpiod工具" | tee -a "$LOG"
        gpiodetect 2>/dev/null | head -3 | tee -a "$LOG"
    else
        echo "✓ 使用传统GPIO接口" | tee -a "$LOG"
    fi
    
    # 检查设备树GPIO信息
    if [[ -d "/proc/device-tree" ]]; then
        local gpio_refs=$(find /proc/device-tree -name "*gpio*" 2>/dev/null | wc -l)
        if [[ $gpio_refs -gt 0 ]]; then
            echo "✓ 设备树中发现 $gpio_refs 个GPIO相关节点" | tee -a "$LOG"
        fi
    fi
    
    echo $result
}

# 执行检查
result=$(check_gpio_support)

if [[ "$result" == "成功" ]]; then
    echo "GPIO功能测试成功" | tee -a "$LOG"
    echo "测试成功"
    exit 0
else
    echo "GPIO功能测试失败" | tee -a "$LOG"
    echo "测试失败"
    exit 1
fi
