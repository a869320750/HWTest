#!/bin/sh
# 蓝牙功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/bt_test.log

# 检查蓝牙设备
if hciconfig 2>/dev/null | grep -q hci; then
    echo "检测到蓝牙设备，尝试扫描周围蓝牙..."
    # 获取第一个蓝牙接口名
    BT_IF=$(hciconfig | awk '/^hci/{print $1; exit}')
    if [ -z "$BT_IF" ]; then
        echo "未找到蓝牙接口名"
        echo "测试失败: 未找到蓝牙接口名" | tee -a "$LOG"
        exit 1
    fi
    # 启动接口（有些系统需手动up）
    hciconfig "$BT_IF" up 2>/dev/null
    # 扫描周围蓝牙设备
    if timeout 20s hcitool -i "$BT_IF" scan | grep -v 'Scanning' | grep -q .; then
        echo "已扫描到蓝牙设备，蓝牙功能正常"
        echo "测试成功" | tee -a "$LOG"
        exit 0
    else
        echo "未扫描到蓝牙设备，建议靠近其他蓝牙终端重试"
        echo "测试失败: 未扫描到蓝牙设备" | tee -a "$LOG"
        exit 1
    fi
else
    echo "未检测到蓝牙设备"
    echo "测试失败: 未检测到蓝牙设备" | tee -a "$LOG"
    exit 1
fi
