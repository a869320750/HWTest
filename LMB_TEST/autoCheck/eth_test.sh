#!/bin/sh
# 以太网功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/eth_test.log

# 1. 检查以太网接口
if ! ifconfig eth0 2>/dev/null | grep -q 'inet '; then
    echo "以太网未连接或未获取到IP"
    echo "测试失败: 以太网未连接或未获取到IP" >> "$LOG"
    echo "测试失败"
    exit 1
fi

# 2. 连通性测试
if ping -c 2 192.168.1.1 2>/dev/null | grep -q 'ttl='; then
    echo "以太网连通，功能正常"
    echo "测试成功" >> "$LOG"
    echo "测试成功"
    exit 0
else
    echo "以太网不通"
    echo "测试失败: 以太网不通" >> "$LOG"
    echo "测试失败"
    exit 1
fi
