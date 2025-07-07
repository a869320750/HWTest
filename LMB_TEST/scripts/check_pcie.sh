#!/bin/sh
echo "===== PCIE设备检测脚本 ====="
echo "check_pcie.sh"
echo "chmod +x check_pcie.sh"
echo "./check_pcie.sh > pcie_check.log 2>&1"
'''
echo "===== lspci ====="
lspci -vv

echo "===== dmesg | grep -i pcie ====="
dmesg | grep -i pcie

echo "===== dmesg | grep -i nvme ====="
dmesg | grep -i nvme

echo "===== dmesg | grep -i sata ====="
dmesg | grep -i sata

echo "===== ls /sys/bus/pci/devices/ ====="
ls /sys/bus/pci/devices/

echo "===== cat /proc/iomem | grep -i pci ====="
cat /proc/iomem | grep -i pci

echo "===== lsblk ====="
lsblk

echo "===== fdisk -l ====="
fdisk -l

echo "===== 检查PCIE设备是否识别 ====="
if lspci | grep -iq 'nvme\\|sata\\|storage\\|pci bridge'; then
    echo "PCIE设备识别正常，OK"
else
    echo "未检测到PCIE存储或桥设备，请检查供电、复位、设备树、驱动等"
fi