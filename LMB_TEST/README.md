# LMB_TEST 目录文档导航

本目录文档已按主要功能拆分，便于查阅和维护。请根据需求点击下方链接：

1. [Type-C/USB（含USB2.0/3.0/OTG/PD等）](docs/typec_usb3.md)
2. [HDMI输出与分辨率切换](docs/hdmi_debug.md) 
3. [UART/串口调试与验证](docs/uart_debug.md)
4. [以太网GMAC调试](docs/ethernet_debug.md)
5. [WiFi/蓝牙调试与排查](docs/wifi_bt_debug.md)
6. [临时需求/批量拉高GPIO](docs/gpio_test.md)
7. [IMU/惯导传感器调试](docs/imu_debug.md)
8. [PCIE接口与自组网模块调试](docs/pcie_debug.md)
9. [RTK与ADS-B模块调试](docs/rtk_adsb_debug.md)

如需详细内容，请进入对应子文档查阅。

---

> 如有新主题或内容，请新建md文件并在此处补充链接。

---

## RK3588 LMB 各功能调通关键patch总结（备忘）

> 需求背景：本人首次调试RK3588平台各硬件功能，踩坑较多，特此记录关键patch及其作用，便于后续维护和复用。

### 1. 设备树适配与基础外设使能

```diff
// 以0002-EVB-2-LMB.patch为例，核心是dts/dtsi大范围适配
-#include "rk3588-evb7-v11.dtsi"
+#include "rk3588-evb7-v11.dtsi" // 适配LMB板型，调整外设节点、引脚复用等
```
**说明**：只有设备树适配到位，后续各外设（如WIFI/BT/IMU等）才能被驱动识别。

### 2. WiFi功能修正

```diff
-    reset-gpios = <&gpio0 RK_PC4 GPIO_ACTIVE_HIGH>;  // 原极性
+    reset-gpios = <&gpio0 RK_PC4 GPIO_ACTIVE_LOW>;   // 修正为实际硬件极性
```
**说明**：WIFI模块上电/复位GPIO极性错误会导致无法识别，修正后WIFI正常。

### 3. 蓝牙功能修正

```diff
-    clock-output-names = "rtc32k";
+    clock-output-names = "ext_clock";
+    status = "okay";  // 确保时钟节点启用
```
**说明**：蓝牙模块依赖外部时钟，节点名和状态需与驱动匹配，否则无法初始化。

### 4. IMU/惯导模块上电

```diff
+    imu_rst_reg: imu-rst-regulator {
+        compatible = "regulator-fixed";
+        regulator-name = "imu_rst";
+        regulator-boot-on;
+        enable-active-high;
+        gpio = <&gpio0 RK_PA7 GPIO_ACTIVE_HIGH>;
+        pinctrl-names = "default";
+        pinctrl-0 = <&imu_rst_h>;
+    };
```
**说明**：IMU模块需单独上电/复位，增加regulator节点后可被正常识别。

### 5. USB/Type-C/PCIE等外设修正

```diff
-    dr_mode = "otg";
-    usb-role-switch;
+    dr_mode = "host";
+    // usb-role-switch;
```
**说明**：部分接口模式需与实际硬件/需求一致，否则无法正常识别或切换。

### 6. RTK/ADS-B/串口等模块

```diff
-    gpio = <&gpio4 RK_PA0 GPIO_ACTIVE_HIGH>;
+    gpio = <&gpio4 RK_PA1 GPIO_ACTIVE_LOW>; // 极性和引脚修正
```
**说明**：串口/模块电源管理GPIO极性和引脚需与原理图一致，否则模块无法上电。

### 7. USB转串口、WIFI等驱动内核配置

```diff
+CONFIG_LINKYUM_PHY=y
+CONFIG_BRCMFMAC=y
+CONFIG_WL_ROCKCHIP=y
```
**说明**：内核未使能相关驱动时，外设即使硬件OK也无法被识别。

---

> 以上为各功能调通的关键patch片段及说明，后续如有新外设或新坑，建议及时补充记录。

---