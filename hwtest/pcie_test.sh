#!/bin/sh
# PCIe功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/pcie_test.log

# 检查PCIe设备
if lspci 2>/dev/null | grep -iq 'nvme\|sata\|ethernet\|pci bridge'; then
    echo "检测到PCIe设备，功能正常"
    echo "测试成功" >> "$LOG"
    echo "测试成功"
    exit 0
else
    echo "未检测到PCIe设备"
    echo "测试失败: 未检测到PCIe设备" >> "$LOG"
    echo "测试失败"
    exit 1
fi
