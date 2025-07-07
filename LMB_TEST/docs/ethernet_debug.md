# 以太网GMAC调试

本节介绍嵌入式平台以太网（GMAC）接口的常见测试方法、调试工具和一键检测脚本，适用于开发板、工控机等场景。

## 功能简介
- 以太网接口用于连接局域网/互联网，实现有线网络通信。
- 常见需求包括：
  - 检查网口物理连接和状态
  - 验证10M/100M/1000M速率
  - 驱动、PHY识别与调试

## 常用工具
- `ifconfig`/`ip addr`：查看网口状态和IP地址
- `ethtool`：查询和设置以太网设备参数
- `dmesg`：查看内核网口/PHY相关日志
- `ping`/`iperf3`：网络连通性和性能测试

## 常用命令
- 查看网口状态：
  - `ifconfig -a`
  - `ip addr`
- 查看驱动和PHY识别日志：
  - `dmesg | grep -i phy`
  - `dmesg | grep -i gmac`
- 查看链路状态：
  - `ethtool eth0`
- 启用网口/获取IP：
  - `ifconfig eth0 up`
  - `udhcpc -i eth0` 或 `dhclient eth0`
- 网络连通性测试：
  - `ping 192.168.1.1`

---

## 附录：以太网一键检测脚本

> 说明：本脚本可一键收集以太网接口状态、驱动日志、链路信息等，便于整体排查。请复制到板子上执行。

```sh
#!/bin/sh

echo "===== 1. 网口状态 ====="
ifconfig -a
ip addr

echo "\n===== 2. 驱动/PHY识别日志 ====="
dmesg | grep -i phy | tail -n 30
dmesg | grep -i gmac | tail -n 30

echo "\n===== 3. 链路状态 ====="
ethtool eth0 2>/dev/null

echo "\n===== 4. 获取IP地址（DHCP） ====="
udhcpc -i eth0 2>/dev/null || dhclient eth0 2>/dev/null

# 连通性测试（可按需修改目标IP）
echo "\n===== 5. 网络连通性测试 ====="
ping -c 4 192.168.1.1 2>/dev/null

# 性能测试（如有iperf3）
if command -v iperf3 >/dev/null; then
  echo "\n===== 6. 网络性能测试（iperf3） ====="
  iperf3 -c 192.168.1.1 -t 5 2>/dev/null
fi

echo "\n===== 检查完成，请结合回显分析以太网功能 ====="
```

> 如需定制检测内容（如指定网口名、目标IP等），可在脚本中补充相应命令。
