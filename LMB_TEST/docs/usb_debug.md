# USB/4G/5G模块检测与调试

本节介绍如何在RK3588平台下检测USB接口及4G/5G模块的识别情况，便于现场快速判断模块是否被系统识别。

## 1. 基本检测方法

### 1.1 查看USB设备树

```sh
lsusb
```
- 可看到所有已识别的USB设备，4G/5G模块通常会显示厂商ID/产品ID。

### 1.2 查看内核日志

插入/拔出模块后，查看最新内核日志：
```sh
dmesg | tail -n 30
```
- 可看到USB设备插入、驱动加载、分配ttyUSB等信息。

### 1.3 检查设备节点

常见4G/5G模块会被识别为串口或网络设备：
```sh
ls /dev/ttyUSB*
ls /dev/cdc-wdm*
ls /dev/wwan*
```
- 出现新节点通常表示模块已被驱动识别。

### 1.4 结合lsusb确认厂商/产品ID

```sh
lsusb
```
- 记录4G/5G模块的ID（如12d1:1506等），可用于后续驱动适配。

## 2. 一键检测脚本示例

可在板卡上新建 usb_check.sh，内容如下：

```sh
#!/bin/sh

echo "[1] 当前USB设备列表："
lsusb

echo "\n[2] 最近内核日志："
dmesg | tail -n 30

echo "\n[3] 检查常见4G/5G设备节点："
ls /dev/ttyUSB* 2>/dev/null
ls /dev/cdc-wdm* 2>/dev/null
ls /dev/wwan* 2>/dev/null
```
- 赋予可执行权限：`chmod +x usb_check.sh`
- 插入模块后运行：`./usb_check.sh`

### 2.1 

## 3. 常见问题排查
- 未识别：检查内核驱动（如option、qmi_wwan、cdc_mbim等）是否编译进内核。
- 识别为存储设备：部分模块需“切换模式”，可用usb_modeswitch工具。
- 识别为多个ttyUSB：一般0/1/2/3分别为AT口、数据口、调试口等，具体见模块手册。

---

如需进一步调试AT指令、拨号联网等，可参考对应模块的官方文档或补充脚本。
