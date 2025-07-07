# 1. Type-C USB3.0 x1 及相关功能

## 1.1 固件烧录  J2600  已OK
- 用官方烧录工具（如RKDevTool、upgrade_tool）烧录固件，确认能正常识别和烧录。
- 作用：通过USB接口，把系统固件（如bootloader、内核、文件系统等）烧录到主控芯片或存储器里。
- 常见场景：开发板首次烧录、系统升级、救砖。
- 实现方式：主控芯片上电后进入“烧录模式”，PC端用专用工具（如RKDevTool、upgrade_tool）通过USB线传输固件。

## 1.2 USB2.0 3.0 OTG功能 host/devcie J2600  已OK
- OTG（On-The-Go）
    - 作用：让设备既能当“主机”（Host），也能当“从机”（Device）。
    - 常见场景：手机通过OTG线连接U盘、鼠标、键盘等外设；也可以连接PC当作U盘、ADB等设备。
    - 实现方式：Type-C或Micro-USB接口支持OTG，硬件和驱动支持模式切换。
    - Host模式：设备作为“主机”，可以识别和管理外部USB设备（如U盘、鼠标、键盘、摄像头等）。
    - Device模式：设备作为“从机”，被PC等主机识别（如U盘模式、ADB调试、串口、网卡等）。
    - 切换方式：有的板子通过硬件ID脚、软件配置或Type-C协议自动切换。
- 测试方法：
- 插U盘、移动硬盘，lsusb、fdisk -l、ls /dev/sd* 检查识别情况。
- 用 dmesg 观察插拔日志。
- 切换Host/Device模式，连接PC看能否识别为设备（如ADB、U盘模式）。
- `lsusb`  
  `fdisk -l`  
  `ls /dev/sd*`  
  `dmesg | tail -n 50`  # 查看插拔日志

## 1.3 PD control I2C 通信（详细功能待定无充电控制，仅数据通信） J2600  已OK
- PD control I2C（USB Power Delivery控制）
    - 作用：通过I2C总线与Type-C PD（Power Delivery）芯片通信，实现高压快充、功率协商等功能。
    - 常见场景：Type-C口支持多种电压/电流档位，主控通过I2C配置PD芯片，决定供电/充电参数。
    - 一般用法：如果只做数据通信，不涉及快充，可以不用管PD控制。

- 如果Type-C PD芯片已禁用，可跳过。
- 若需测试，需用i2cdetect、i2cget、i2cset等工具访问PD芯片地址，确认I2C通信正常。

## 1.4 SY6861B1ABC  5V switch 功能 U2603  已OK
- 作用：通过芯片或外部电路控制USB口的5V供电开关，决定是否给外设供电。
- 常见场景：节能、过流保护、热插拔保护等。
- 实现方式：主控通过GPIO或I2C控制5V开关芯片（如SY6861B1ABC），实现USB口供电的开/关。

---

## 附录：USB接口一键检测脚本

> 说明：本脚本可一键收集Type-C/USB/OTG/PD/5V Switch等相关状态和日志，便于整体排查。请复制到板子上执行。

```sh
#!/bin/sh

echo "===== 1. 基础USB设备检测 ====="
lsusb
fdisk -l
echo "\n当前块设备："
ls /dev/sd*

echo "\n===== 2. dmesg日志（最近50行） ====="
dmesg | tail -n 50

echo "\n===== 3. OTG/Host模式状态（如有） ====="
ls /sys/class/udc 2>/dev/null
cat /sys/class/udc/*/state 2>/dev/null

# PD/I2C相关（如有PD芯片/I2C总线）
echo "\n===== 4. PD芯片I2C检测（如有） ====="
i2cdetect -l 2>/dev/null
i2cdetect -y 0 2>/dev/null  # 0号I2C总线，实际编号请根据硬件调整
i2cdetect -y 1 2>/dev/null  # 1号I2C总线

# 5V Switch相关（如有GPIO控制）
echo "\n===== 5. 5V Switch GPIO状态（如有） ====="
cat /sys/kernel/debug/gpio | grep -i '5v\|usb\|switch' 2>/dev/null

# 供电/电流检测（如有）
echo "\n===== 6. 电源/电流状态（如有） ====="
cat /sys/class/power_supply/*/uevent 2>/dev/null

# 结束
echo "\n===== 检查完成，请结合回显分析USB相关功能 ====="
```

> 如需定制检测内容（如指定PD芯片地址、特定GPIO编号等），可在脚本中补充相应命令。
