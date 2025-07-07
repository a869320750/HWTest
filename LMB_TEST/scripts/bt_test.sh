#!/bin/bash
# filepath: bt_test.sh

# 在开发板上执行用以测试蓝牙功能情况
'''
chmod +x bt_test.sh
./bt_test.sh
'''

echo "========================================="
echo "蓝牙功能测试脚本 - $(date)"
echo "========================================="

echo ""
echo "1. 检查蓝牙相关内核日志..."
echo "----------------------------------------"
dmesg | grep -i bluetooth | tail -10
echo ""
dmesg | grep -i bt | grep -v "orbit" | tail -10
echo ""
dmesg | grep -i hci | tail -10

echo ""
echo "2. 检查蓝牙固件文件..."
echo "----------------------------------------"
echo "BCM4354相关固件:"
ls -la /lib/firmware/BCM4354* 2>/dev/null || echo "未找到BCM4354固件"
echo ""
echo "所有蓝牙相关固件:"
ls -la /lib/firmware/BCM*.hcd 2>/dev/null || echo "未找到.hcd固件文件"

echo ""
echo "3. 检查蓝牙设备接口..."
echo "----------------------------------------"
echo "HCI设备列表:"
hciconfig -a 2>/dev/null || echo "hciconfig命令不可用或无HCI设备"
echo ""
echo "蓝牙控制器状态:"
if command -v bluetoothctl >/dev/null 2>&1; then
    timeout 3 bluetoothctl list 2>/dev/null || echo "bluetoothctl超时或无设备"
else
    echo "bluetoothctl命令不可用"
fi

echo ""
echo "4. 检查UART设备..."
echo "----------------------------------------"
echo "UART设备列表:"
ls -la /dev/ttyS* 2>/dev/null || echo "未找到UART设备"
echo ""
echo "UART相关内核日志:"
dmesg | grep -i uart | grep -E "(uart9|ttyS)" | tail -5

echo ""
echo "5. 检查GPIO和pinctrl状态..."
echo "----------------------------------------"
echo "蓝牙相关GPIO错误:"
dmesg | grep -i "gpio.*bluetooth\|bluetooth.*gpio" | tail -5
echo ""
echo "pinctrl相关错误:"
dmesg | grep -i "pinctrl.*bluetooth\|bluetooth.*pinctrl" | tail -5

echo ""
echo "6. 检查rfkill状态..."
echo "----------------------------------------"
if [ -d /sys/class/rfkill/ ]; then
    echo "rfkill设备:"
    for rfkill in /sys/class/rfkill/rfkill*; do
        if [ -d "$rfkill" ]; then
            name=$(cat "$rfkill/name" 2>/dev/null)
            type=$(cat "$rfkill/type" 2>/dev/null)
            state=$(cat "$rfkill/state" 2>/dev/null)
            echo "  $(basename $rfkill): $name ($type) - state: $state"
        fi
    done
else
    echo "未找到rfkill设备"
fi

echo ""
echo "7. 检查最新的蓝牙初始化错误..."
echo "----------------------------------------"
echo "最近的蓝牙相关错误:"
dmesg | grep -i "error\|fail\|timeout" | grep -i "bt\|bluetooth\|hci" | tail -10

echo ""
echo "8. 尝试基本蓝牙操作..."
echo "----------------------------------------"
if command -v hciconfig >/dev/null 2>&1; then
    echo "尝试启用蓝牙设备:"
    hciconfig hci0 up 2>&1 || echo "启用蓝牙失败"
    echo ""
    echo "蓝牙设备信息:"
    hciconfig hci0 2>&1 || echo "获取蓝牙设备信息失败"
else
    echo "hciconfig命令不可用"
fi

echo ""
echo "========================================="
echo "蓝牙测试完成 - $(date)"
echo "========================================="