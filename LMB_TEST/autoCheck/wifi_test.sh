#!/bin/sh
# WiFi功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/wifi_test.log

# 1. 检查无线网卡
if ! iwconfig 2>&1 | grep -v 'no wireless extensions' | grep -q 'IEEE'; then
    echo "未检测到无线网卡"
    echo "测试失败: 未检测到无线网卡" >> "$LOG"
    echo "测试失败"
    exit 1
fi

# 2. 检查网络连接
if ifconfig wlan0 2>/dev/null | grep -q 'inet '; then
    echo "WiFi已连接，功能正常"
    echo "测试成功" >> "$LOG"
    echo "测试成功"
    exit 0
else
    echo "WiFi未连接，尝试扫描热点..."
    iwlist wlan0 scan | grep 'ESSID' || echo "扫描失败"
    echo "测试失败: WiFi未连接" >> "$LOG"
    echo "测试失败"
    exit 1
fi
