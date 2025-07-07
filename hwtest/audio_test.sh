#!/bin/sh
# 音频功能一键检测脚本，适配hwtest主控

LOG=/tmp/hw_test_logs/audio_test.log

# 检查声卡设备
if aplay -l 2>/dev/null | grep -q 'card'; then
    echo "检测到声卡设备，功能正常"
    echo "测试成功" >> "$LOG"
    echo "测试成功"
    exit 0
else
    echo "未检测到声卡设备"
    echo "测试失败: 未检测到声卡设备" >> "$LOG"
    echo "测试失败"
    exit 1
fi
