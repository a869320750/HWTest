#!/bin/sh
echo "===== 串口监控脚本 ====="

echo "chmod +x monitor_serial.sh"
echo "./monitor_serial.sh"

while true; do
    cat /dev/ttyS4 | while read line; do
        echo "[ttyS4] $line"
    done &
    cat /dev/ttyS7 | while read line; do
        echo "[ttyS7] $line"
    done &
    wait
    cat /dev/ttyUSB0 | while read line; do
        echo "[ttyUSB0] $line"
    done &
    wait
done