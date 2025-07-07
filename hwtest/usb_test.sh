#!/bin/sh
# USB功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/usb_test.log

# 检查USB设备
if lsusb 2>/dev/null | grep -q 'ID'; then
    echo "检测到USB设备，功能正常"
    echo "测试成功" >> "$LOG"
    echo "测试成功"
    exit 0
else
    echo "未检测到USB设备"
    echo "测试失败: 未检测到USB设备" >> "$LOG"
    echo "测试失败"
    exit 1
fi
