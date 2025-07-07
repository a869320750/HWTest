# 临时需求/批量拉高GPIO

## 请把这些gpio拉高，给我一个固件版本。我来验证下功能扩展板的各路电压
```sh
GPIO3_D5_D: 125
GPIO3_D2_D: 122
GPIO1_B3_D: 43
GPIO3_D3_D: 123
GPIO3_C7_U: 119


echo 125 > /sys/class/gpio/export
cat /sys/class/gpio/gpio125/value
cat /sys/class/gpio/gpio125/direction

echo 122 > /sys/class/gpio/export
cat /sys/class/gpio/gpio122/value
cat /sys/class/gpio/gpio122/direction

echo 43 > /sys/class/gpio/export
cat /sys/class/gpio/gpio43/value
cat /sys/class/gpio/gpio43/direction

echo 123 > /sys/class/gpio/export
cat /sys/class/gpio/gpio123/value
cat /sys/class/gpio/gpio123/direction

echo 119 > /sys/class/gpio/export
cat /sys/class/gpio/gpio119/value
cat /sys/class/gpio/gpio119/direction


可以通过
cat /sys/kernel/debug/gpio
查看占用，形式如下：
...（可补充更多GPIO相关经验）
