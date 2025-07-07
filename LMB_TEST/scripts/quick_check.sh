#!/bin/sh
echo "===== 快速功能检测脚本 ====="

# 1. USB 设备检测
echo
echo "【USB设备检测】"
lsusb
fdisk -l | grep '^Disk /dev/sd'
ls /dev/sd* 2>/dev/null

# 2. 以太网检测
echo
echo "【以太网检测】"
ifconfig | grep -A1 'eth\|enp'
ip addr | grep -A2 'eth\|enp'
ping -c 2 8.8.8.8 >/dev/null 2>&1 && echo "网络可达" || echo "网络不可达"

# 3. HDMI检测
echo
echo "【HDMI检测】"
modetest -c | grep -A5 connected

# 4. I2C总线检测（以i2c-0为例，可根据实际修改）
echo
echo "【I2C总线检测】"
i2cdetect -y 0 2>/dev/null || echo "i2cdetect 工具或i2c-0不可用"

# 5. UART串口节点检测
echo
echo "【UART串口节点检测】"
ls /dev/ttyS* /dev/ttyUSB* 2>/dev/null

# 6. WiFi检测
echo
echo "【WiFi检测】"
iwconfig 2>/dev/null | grep -v 'no wireless extensions' || echo "未检测到无线网卡"

# 7. 蓝牙检测
echo
echo "【蓝牙检测】"
hciconfig 2>/dev/null | grep hci || echo "未检测到蓝牙设备"

echo
echo "===== 检测完成 ====="

# 结果
# 检测了一下，大概结果如下

# root@rk3588-buildroot:/root# ./quick_check.sh
# ===== 快速功能检测脚本 =====

# 【USB设备检测】
# Bus 005 Device 001: ID 1d6b:0002
# Bus 003 Device 001: ID 1d6b:0001
# Bus 001 Device 001: ID 1d6b:0002
# Bus 006 Device 001: ID 1d6b:0003
# Bus 004 Device 001: ID 1d6b:0001
# Bus 002 Device 001: ID 1d6b:0002

# 【以太网检测】
# 2: eth0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop qlen 1000
#     link/ether 9e:70:bc:67:49:7a brd ff:ff:ff:ff:ff:ff
# 网络不可达

# 【HDMI检测】
# 208     0       disconnected    HDMI-A-1        0x0             0       207
#   props:
#         1 EDID:
#                 flags: immutable blob
#                 blobs:

# --
# 224     223     connected       DSI-1           1920x1080               1       223
#   modes:
#         index name refresh (Hz) hdisp hss hse htot vdisp vss vse vtot
#   #0 1080x1920 59.90 1080 1095 1099 1129 1920 1935 1937 1952 132000 flags: nhsync, nvsync; type: preferred, driver
#   props:
#         1 EDID:

# 【I2C总线检测】
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 00:                         -- -- -- -- -- -- -- --
# 10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 40: -- -- UU UU -- -- -- -- -- -- -- -- -- -- -- --
# 50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# 70: -- -- -- -- -- -- -- --

# 【UART串口节点检测】
#  /dev/ttyS0   /dev/ttyS9

# 【WiFi检测】
# 未检测到无线网卡

# 【蓝牙检测】
# 未检测到蓝牙设备

# ===== 检测完成 =====
# root@rk3588-buildroot:/root#
