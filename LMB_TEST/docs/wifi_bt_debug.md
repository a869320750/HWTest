# 6. WiFi/蓝牙调试与排查

## 6. WIFI、蓝牙功能验证 U6200

### 6.1 基本检查命令
- **WiFi**：iwconfig、ifconfig、nmcli、iwlist scan 搜索并连接热点，测试网络通信。
- **蓝牙**：bluetoothctl 搜索、配对、连接蓝牙设备。

```bash
# WiFi检查
iwconfig
iwlist scan
nmcli
ifconfig

# 蓝牙检查
bluetoothctl
```

### 6.2 WIFI/BT模块硬件信号说明

#### 6.2.1 供电相关
- **VBAT、VCC3V3_WL_VBAT、VIN_LDO**：主供电，必须上电且电压正常
- **WL_REG_ON（WL_EN）**：WiFi使能脚，上电后需拉高，模块才会启动
- **BT_REG_ON**：蓝牙使能脚，上电后需拉高，蓝牙部分才会启动

#### 6.2.2 复位/唤醒信号
- **WL_HOST_WAKE、BT_HOST_WAKE、BT_WAKE**：主控与模块之间的唤醒信号，通常可选，部分平台需要配置
- **NC/NC/PCIE_PREST_L、NC/NC/PCIE_CLKREQ_L**：如用PCIe接口时关注，SDIO/USB模式可忽略

#### 6.2.3 通信接口
- **SDIO_DATA_0~3、SDIO_CMD、SDIO_CLK**：WiFi用的SDIO总线（如果你用SDIO模式）
- **UART_TXD、UART_RXD、UART_CTS_N、UART_RTS_N**：蓝牙HCI通信用的UART（通常至少要TXD/RXD，流控可选）
- **BT_PCM_*、PCM_*、I2S_* 等**：音频接口，通常蓝牙语音用，普通数据通信可忽略

#### 6.2.4 天线与地
- **WL_ANT、BT_ANT**：天线接口，确保天线焊接良好
- **GND**：地线，必须可靠连接

#### 6.2.5 其它
- **XTAL_IN/OUT**：外部晶振，通常硬件已设计好，无需软件关注

### 6.3 设备树GPIO配置说明
- **bt_irq_gpio**：一般对应 BT_HOST_WAKE（蓝牙模块唤醒主控），需要和原理图实际连接的 GPIO 保持一致
- **bt_wake_gpio**：一般对应 BT_WAKE（主控唤醒蓝牙模块），同样要和原理图一致
- **bt_reset_gpio**：一般对应 BT_REG_ON 或 BT_RESET_N（蓝牙模块复位/上电），也要和原理图一致

### 6.4 WiFi/BT调试诊断脚本

测试wifi功能
```sh
# 1 清理之前的进程和文件
killall wpa_supplicant
rm -f /var/run/wpa_supplicant/wlan0
mkdir -p /var/run/wpa_supplicant

# 2 创建WiFi配置文件
cat > /etc/wpa_supplicant.conf << EOF
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=0
update_config=1

network={
    ssid="DKKJ_SH_5G"   # 换成你的WIFI名字
    psk="dkkj1125"      # 换成你的WIFI密码
}
EOF

# 启动wpa_supplicant（后台运行）
wpa_supplicant -i wlan0 -c /etc/wpa_supplicant.conf -D nl80211 -B

# 检查连接状态
iw wlan0 link

# 获取IP地址
udhcpc -i wlan0
```

```sh
# 1. 查看蓝牙适配器状态
hciconfig -a

# 2. 启动蓝牙适配器（如未UP）
hciconfig hci0 up

# 3. 扫描附近蓝牙设备
hcitool scan

# 4. 进入交互式蓝牙管理，进行配对/连接/信任等
bluetoothctl
# 在 bluetoothctl 交互界面中依次输入：
# power on
# agent on
# default-agent
# scan on
# pair <MAC>
# connect <MAC>
# trust <MAC>

# 5. 查看已配对设备
bluetoothctl paired-devices

# 6. 查看蓝牙服务
sdptool browse <MAC>
```

### 6.5 调试总结与问题分析
...existing code...

### 6.6 REG_ON引脚电压异常排查
...existing code...
