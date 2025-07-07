# IMU/惯导传感器调试

本节简要记录IMU（如BNO085）模块的硬件连接、设备树配置和最常用的串口调试方法，适合现场快速验证。

## 硬件与配置要点
- IMU型号：BNO085（或实际型号，需与硬件确认）
- 通信方式：UART（硬件已焊死为UART模式，PS0/PS1已固定）
- 主要引脚：
    - UART1_TX_M1 → GPIO1_B6_u
    - UART1_RX_M1 → GPIO1_B7_u
    - IMU_RST → GPIO0_A7_u（复位脚）
- 设备树配置：
    - 已删除I2C相关节点
    - UART1配置为mode1复用，波特率115200
    - IMU_RST配置为GPIO输出，系统上电自动拉高

## 快速测试方法
- 验证IMU通过UART1输出数据，数据格式和速率正确
- 验证IMU_RST脚能正常复位IMU模块

```sh
# 设置串口波特率
stty -F /dev/ttyS1 speed 115200 cs8 -echo
# 建议执行两遍确保生效
stty -F /dev/ttyS1 speed 115200 cs8 -echo
# 读取IMU串口数据
cat /dev/ttyS1
```

> 只需如上三步，即可完成IMU串口数据的基本验证。

---

如需进一步解析IMU数据或自动化采集，可结合Python/串口工具等扩展。
