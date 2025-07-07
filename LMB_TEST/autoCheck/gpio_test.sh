#!/bin/sh
# GPIO功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/gpio_test.log

# 以实际需求为准，这里以批量拉高并检测为例
GPIONUMS="125 122 43 123 119"
ALL_OK=1
for gpio in $GPIONUMS; do
    echo $gpio > /sys/class/gpio/export 2>/dev/null
    echo out > /sys/class/gpio/gpio$gpio/direction 2>/dev/null
    echo 1 > /sys/class/gpio/gpio$gpio/value 2>/dev/null
    val=$(cat /sys/class/gpio/gpio$gpio/value 2>/dev/null)
    if [ "$val" != "1" ]; then
        echo "GPIO $gpio 拉高失败" >> "$LOG"
        ALL_OK=0
    fi
    echo "GPIO $gpio 状态: $val" >> "$LOG"
done
if [ $ALL_OK -eq 1 ]; then
    echo "测试成功" >> "$LOG"
    echo "测试成功"
    exit 0
else
    echo "测试失败: 部分GPIO未拉高" >> "$LOG"
    echo "测试失败"
    exit 1
fi
