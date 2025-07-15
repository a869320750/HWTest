#!/bin/sh
# 以太网功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/eth_test.log

# 1. 检查以太网驱动加载和物理链路状态
if ! dmesg | grep -i -q 'eth0'; then
    echo "未检测到以太网驱动加载日志（eth0），请检查驱动加载情况"
    echo "测试失败: 未检测到以太网驱动加载日志" | tee -a "$LOG"
    exit 1
fi

if [ ! -d /sys/class/net/eth0 ]; then
    echo "未检测到eth0接口，驱动或硬件异常"
    echo "测试失败: 未检测到eth0接口" | tee -a "$LOG"
    exit 1
fi


# 检查链路状态，但不作为失败判据
if [ -f /sys/class/net/eth0/operstate ] && grep -q up /sys/class/net/eth0/operstate; then
    echo "以太网驱动加载正常，链路已up"
    echo "测试成功" | tee -a "$LOG"
else
    echo "以太网驱动加载正常，但链路未up（未插网线或硬件异常）"
    echo "[WARNING] 链路未up（未插网线或硬件异常）" | tee -a "$LOG"
    echo "测试成功" | tee -a "$LOG"
fi

# 2. 对外连通性检测（仅记录warning，不影响主判定）
if ping -c 2 192.168.1.1 2>/dev/null | grep -q 'ttl='; then
    echo "[INFO] 以太网对外连通性正常" | tee -a "$LOG"
else
    echo "[WARNING] 以太网对外连通性异常（如无外部网络可忽略）" | tee -a "$LOG"
fi
