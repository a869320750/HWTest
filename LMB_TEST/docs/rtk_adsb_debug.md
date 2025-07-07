# RTK与ADS-B模块调试

本节简要记录RTK与ADS-B模块的硬件连接、设备树配置和最常用的串口调试方法，适合现场快速验证。

## 硬件与配置要点
- RTK模块：通常通过UART4（TX/RX/RTK_PPS）与主控连接。
- ADS-B模块：通常通过UART7（TX/RX）与主控连接。
- 具体引脚分配请参考原理图和设备树。
- 设备树配置：确保`&uart4`和`&uart7`节点已配置并`status = "okay"`，pinctrl分配与硬件一致。

## 快速测试方法
- 配置串口参数：
  ```sh
  stty -F /dev/ttyS4 speed 115200 cs8 -echo
  stty -F /dev/ttyS7 speed 115200 cs8 -echo
  ```
- 监控串口数据：
  ```sh
  cat /dev/ttyS4   # RTK数据
  cat /dev/ttyS7   # ADS-B数据
  ```
- 可用shell脚本同时监控两个串口：
  ```sh
  (cat /dev/ttyS4 | while read line; do echo "[ttyS4] $line"; done) &
  (cat /dev/ttyS7 | while read line; do echo "[ttyS7] $line"; done) &
  wait
  ```

> 只需如上几步，即可完成RTK/ADS-B串口数据的基本验证。

---

如需进一步解析数据或自动化采集，可结合Python/串口工具等扩展。
