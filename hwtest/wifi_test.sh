#!/bin/bash
# WiFi功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/wifi_test.log

echo "开始WiFi功能测试..." | tee -a "$LOG"

# 自动获取第一个无线网卡名
WIFI_IF=$(iw dev | awk '$1=="Interface"{print $2; exit}')
if [ -z "$WIFI_IF" ]; then
    echo "未检测到无线网卡" | tee -a "$LOG"
    echo "测试失败: 未检测到无线网卡" >> "$LOG"
    echo "测试失败"
    exit 1
fi

echo "检测到WiFi接口: $WIFI_IF" | tee -a "$LOG"

# 检查WiFi功能的多种方式
check_wifi_function() {
    local result="成功"
    
    # 1. 检查接口状态
    echo "1. 检查WiFi接口状态..." | tee -a "$LOG"
    if ip link show "$WIFI_IF" >/dev/null 2>&1; then
        local state=$(ip link show "$WIFI_IF" | grep -o 'state [A-Z]*' | awk '{print $2}')
        echo "   接口状态: $state" | tee -a "$LOG"
    fi
    
    # 2. 检查是否已连接
    echo "2. 检查连接状态..." | tee -a "$LOG"
    local link_status=$(iw dev "$WIFI_IF" link 2>/dev/null)
    if echo "$link_status" | grep -q "Connected to"; then
        local ssid=$(echo "$link_status" | grep "SSID:" | awk '{print $2}')
        local freq=$(echo "$link_status" | grep "freq:" | awk '{print $2}')
        echo "   ✓ 已连接到: $ssid (频率: ${freq}MHz)" | tee -a "$LOG"
        echo "   WiFi功能正常 - 当前已连接" | tee -a "$LOG"
        return 0
    else
        echo "   当前未连接WiFi" | tee -a "$LOG"
    fi
    
    # 3. 检查IP地址
    echo "3. 检查IP地址..." | tee -a "$LOG"
    local ip_addr=$(ip addr show "$WIFI_IF" | grep -o 'inet [0-9.]*' | awk '{print $2}')
    if [ -n "$ip_addr" ]; then
        echo "   ✓ 已获取IP地址: $ip_addr" | tee -a "$LOG"
        echo "   WiFi功能正常 - 已获取IP" | tee -a "$LOG"
        return 0
    fi
    
    # 4. 尝试扫描热点（如果未连接）
    echo "4. 尝试扫描WiFi热点..." | tee -a "$LOG"
    local scan_result=$(iw dev "$WIFI_IF" scan 2>&1)
    if echo "$scan_result" | grep -q "BSS\|SSID"; then
        local ssid_count=$(echo "$scan_result" | grep -c "SSID:")
        echo "   ✓ 扫描到 $ssid_count 个WiFi热点" | tee -a "$LOG"
        echo "   WiFi功能正常 - 扫描成功" | tee -a "$LOG"
        return 0
    elif echo "$scan_result" | grep -q "Device or resource busy"; then
        echo "   WiFi设备忙碌(可能已连接) - 这是正常的" | tee -a "$LOG"
        echo "   WiFi功能正常 - 设备正在使用中" | tee -a "$LOG"
        return 0
    else
        echo "   ✗ 扫描失败: $scan_result" | tee -a "$LOG"
        result="失败"
    fi
    
    # 5. 检查驱动和硬件
    echo "5. 检查驱动状态..." | tee -a "$LOG"
    if dmesg | grep -i "$WIFI_IF\|wifi\|wlan" | tail -3 | tee -a "$LOG"; then
        echo "   驱动日志检查完成" | tee -a "$LOG"
    fi
    
    if [ "$result" = "失败" ]; then
        return 1
    else
        return 0
    fi
}

# 执行检查
if check_wifi_function; then
    echo "WiFi功能测试成功" | tee -a "$LOG"
    echo "测试成功"
    exit 0
else
    echo "WiFi功能测试失败" | tee -a "$LOG"
    echo "测试失败"
    exit 1
fi