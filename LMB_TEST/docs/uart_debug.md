# UART/串口调试与一键检测

本节介绍嵌入式平台常见的UART/串口调试方法，适用于多路串口批量验证、自动化测试和常规收发数据场景。

## 基本说明
- UART（通用异步收发器）是最常见的串口通信硬件模块。
- 常见调试需求：
  - 检查串口收发是否正常
  - 批量测试多路串口
  - 自动化收发数据、查看波特率等

## 常用命令
- 设置波特率并收发数据：
  ```sh
  stty -F /dev/ttyS0 speed 115200 cs8 -echo
  cat /dev/ttyS0
  # 新开一个终端
  echo 123 > /dev/ttyS0
  ```
- 可用 minicom、screen、picocom 等工具辅助收发。

---

## 一键批量UART测试脚本

> 说明：本脚本可自动向多路串口周期性发送数据，便于批量验证收发功能。请根据实际串口编号调整。

```sh
#!/bin/sh
# filepath: test_uart.sh

# 设置波特率为115200（如有多路串口可批量设置）
stty -F /dev/ttyS0 115200
stty -F /dev/ttyS3 115200
stty -F /dev/ttyS6 115200
stty -F /dev/ttyUSB0 115200

while true; do
    echo "UART0 test $(date)" > /dev/ttyS0
    echo "UART3 test $(date)" > /dev/ttyS3
    echo "UART6 test $(date)" > /dev/ttyS6
    echo "UARTUSB0 test $(date)" > /dev/ttyUSB0
    sleep 1
done
```

使用方法：
```sh
chmod +x test_uart.sh
./test_uart.sh &
```

> 如需收集所有串口日志，可在另一个终端用 `cat /dev/ttyS*` 方式批量查看。

---

## 批量串口后台监控脚本

> 说明：本脚本可持续后台监控多个串口，有新数据时自动打印到终端，适合批量收集串口输出。

```sh
#!/bin/sh
# filepath: monitor_uart.sh

# 需要监控的串口列表（可根据实际情况增减）
UART_LIST="/dev/ttyS0 /dev/ttyS3 /dev/ttyS6 /dev/ttyUSB0"

# 先给所有串口设置波特率115200
echo "正在配置串口波特率..."
for dev in $UART_LIST; do
  if [ -e "$dev" ]; then
    stty -F "$dev" 115200 cs8 -echo
    echo "已配置 $dev 波特率为115200"
  else
    echo "警告: $dev 不存在，跳过配置"
  fi
done

echo "开始监控串口数据..."

for dev in $UART_LIST; do
  (
    while true; do
      if [ -e "$dev" ]; then
        cat "$dev" | while read line; do
          echo "[$dev] $line"
        done
      else
        sleep 1
      fi
    done
  ) &
done

wait
```

使用方法：
```sh
chmod +x monitor_uart.sh
./monitor_uart.sh
```

> 可根据实际串口编号修改 UART_LIST。此脚本会持续后台监控所有指定串口，有新数据即打印。

---

如需定制更多串口编号、波特率或自动化收发逻辑，可在脚本中补充相应命令。
