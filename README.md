# 🔧 HWTest - 专业硬件测试工具集

<div align="center">

![Version](https://img.shields.io/badge/version-v2.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-RK3588-green.svg)
![Shell](https://img.shields.io/badge/shell-bash-orange.svg)
![License](https://img.shields.io/badge/license-MIT-red.svg)

**为嵌入式硬件开发者打造的一站式测试解决方案**

</div>

## 📋 目录

- [✨ 特性](#-特性)
- [🚀 快速开始](#-快速开始)
- [🛠️ 功能模块](#️-功能模块)
- [📚 使用指南](#-使用指南)
- [🔧 高级功能](#-高级功能)
- [📊 开发统计](#-开发统计)
- [🤝 贡献指南](#-贡献指南)

## ✨ 特性

### 🎯 双重设计理念
- **硬件工程师**: 一键式全面测试 (`hwtest all`)
- **软件工程师**: 精细化调试工具集

### 🛡️ 安全可靠
- 多重安全检查机制
- 防误操作保护
- 详细的错误处理

### 📈 专业报告
- HTML格式硬件体检报告
- 实时状态监控
- 历史数据记录

## 🚀 快速开始

### 安装部署

```bash
# 克隆项目
git clone https://github.com/a869320750/HWTest.git
cd HWTest/hwtest

# 部署到系统 (适用于RK3588平台)
sudo ./publish_hwtest.sh

# 快速测试
hwtest --help
```

### 一键硬件检测

```bash
# 硬件工程师专用 - 全面检测
hwtest all

# 生成专业HTML报告
hwtest report
```

## 🛠️ 功能模块

### 📡 基础硬件测试
```bash
hwtest wifi      # WiFi功能测试
hwtest bt        # 蓝牙功能测试  
hwtest eth       # 以太网测试
hwtest usb       # USB设备测试
hwtest audio     # 音频功能测试
hwtest pcie      # PCIe设备测试
```

### 🔌 GPIO调试工具集
```bash
# GPIO名称解析 - 智能转换Rockchip GPIO格式
hwtest gpio parse GPIO3_D2_D

# GPIO操作
hwtest gpio set GPIO3_D2_D 1      # 设置高电平
hwtest gpio get GPIO3_D2_D -w     # 实时监控
hwtest gpio scan --summary        # 系统概览

# 批量操作
hwtest gpio batch --generate > config.txt  # 生成配置模板
hwtest gpio batch -f config.txt            # 执行批量操作
```

**GPIO解析示例输出:**
```
==========================================
GPIO名称解析结果: GPIO3_D2_D
==========================================
Bank号:     3
组:         D (索引: 3)
组内编号:   2
Pin号:      26
SysFS编号:  122
上下拉:     down

设备树配置:
----------------------------------------
gpio3-d2-d-out: gpio3-d2-d-out {
    rockchip,pins = <3 26 RK_FUNC_GPIO &pcfg_pull_down>;
};

SysFS操作命令:
----------------------------------------
echo 122 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio122/direction
echo 1 > /sys/class/gpio/gpio122/value
```

### 📺 UART调试工具集
```bash
# 串口扫描和配置
hwtest uart scan                    # 扫描所有串口
hwtest uart config /dev/ttyS0 -b 115200

# 数据收发
hwtest uart monitor /dev/ttyS0      # 监控串口数据
hwtest uart send /dev/ttyS0 "Hello" # 发送数据

# 性能测试
hwtest uart loopback /dev/ttyS0     # 环回测试
```

### 💾 存储测试工具集
```bash
# 存储设备管理
hwtest storage scan                 # 扫描存储设备
hwtest storage speed /dev/sda       # 性能测试
hwtest storage health               # 健康检查

# 安全格式化 (多重保护)
hwtest storage format --list        # 列出可安全格式化的设备
hwtest storage format --dry-run -d /dev/sdb1  # 预览操作
```

### 📊 系统监控工具集
```bash
# 实时监控
hwtest monitor thermal              # 温度监控
hwtest monitor cpu                  # CPU监控
hwtest monitor memory               # 内存监控
hwtest monitor power                # 功耗监控
```

## 📚 使用指南

### GPIO批量配置示例

创建GPIO配置文件 `led_control.txt`:
```bash
# LED控制配置
GPIO3_D2_D:out:1:红色LED
GPIO3_D3_D:out:0:绿色LED  
GPIO3_D4_D:out:1:蓝色LED
GPIO4_A0_U:out:1:电源开关
```

执行批量操作:
```bash
hwtest gpio batch -f led_control.txt -v
```

### 温度监控和告警

```bash
# 实时温度监控，80°C告警
hwtest monitor thermal -w 1 -t 80 -a

# 记录温度日志
hwtest monitor thermal -w 5 -l /tmp/thermal.log
```

### 串口环回测试

```bash
# 高频测试，检测稳定性
hwtest uart loopback /dev/ttyS0 -c 100 -b 921600
```

## 🔧 高级功能

### 自定义测试脚本

HWTest支持自定义测试脚本，只需将脚本放在指定目录并遵循命名规范:

```bash
# 脚本位置
/usr/local/bin/hw_test/custom_test.sh

# 脚本必须输出特定关键词
echo "测试成功"  # 或 "功能正常" 或 "OK"
```

### HTML报告定制

生成的HTML报告包含:
- 📊 硬件测试统计图表
- 🔍 详细的系统信息表格
- 📈 实时状态更新
- 💾 可导出和分享

### 安全特性

**存储格式化保护:**
- ✅ 仅支持可移动设备
- ❌ 禁止系统关键分区
- 🔐 多重确认机制
- 👁️ 预览模式

## 📊 开发统计

### 📈 代码量统计
```
总计: ~3500行 高质量Bash代码

模块分布:
├── GPIO工具集:    ~1400行 (40%)
├── UART工具集:    ~1000行 (29%) 
├── 存储工具集:    ~500行  (14%)
├── 监控工具集:    ~400行  (11%)
└── 核心框架:      ~200行  (6%)
```

### 🛠️ 功能特性统计
- **28个** 独立工具脚本
- **6大** 功能模块
- **50+** 命令选项
- **多重** 安全保护机制

### ⏱️ 开发工作量
预估纯手工开发需要: **2-3周** 全职工作量

包含:
- 需求分析和架构设计
- 算法实现(GPIO解析等)
- 错误处理和边界情况
- 安全机制设计
- 用户体验优化
- 测试和调试

## 🔧 目录结构

```
hwtest/
├── main_test.sh          # 🎯 主入口脚本
├── publish_hwtest.sh     # 📦 部署脚本
├── *_test.sh            # 🧪 基础硬件测试脚本
├── gpio/                # 🔌 GPIO调试工具集
│   ├── gpio_menu.sh     #   ├─ 主菜单
│   ├── gpio_parser.sh   #   ├─ 名称解析
│   ├── gpio_setter.sh   #   ├─ GPIO设置  
│   ├── gpio_getter.sh   #   ├─ GPIO读取
│   ├── gpio_batch.sh    #   ├─ 批量操作
│   └── ...              #   └─ 其他工具
├── uart/                # 📺 UART调试工具集
│   ├── uart_menu.sh     #   ├─ 主菜单
│   ├── uart_scanner.sh  #   ├─ 串口扫描
│   ├── uart_monitor.sh  #   ├─ 数据监控
│   └── ...              #   └─ 其他工具
├── storage/             # 💾 存储测试工具集
├── monitor/             # 📊 系统监控工具集
└── tools/               # 🛠️ 辅助工具
    └── hardware_report.sh # 📋 报告生成器
```

## 🎯 适用场景

### 硬件工程师
- ✅ **快速验证**: 新硬件板卡功能验证
- 📋 **批量测试**: 生产线硬件检测  
- 📊 **问题诊断**: 硬件故障快速定位

### 软件工程师  
- 🔧 **驱动调试**: GPIO、UART等驱动开发
- 📈 **性能分析**: 系统性能瓶颈分析
- 🛠️ **接口测试**: 硬件接口通信测试

### 测试工程师
- 🔄 **自动化测试**: CI/CD集成硬件测试
- 📝 **测试报告**: 标准化测试文档
- 🔍 **回归测试**: 版本间硬件兼容性

## 🚀 性能特点

- **⚡ 轻量级**: 纯Bash实现，无额外依赖
- **🔧 模块化**: 独立模块，按需使用
- **🛡️ 安全性**: 多重保护，防误操作
- **📱 易用性**: 直观命令，清晰输出
- **🔄 可扩展**: 易于添加新功能模块

## 📂 传统硬件调试资源

本项目在构建现代化工具集的同时，也保留了丰富的传统硬件调试经验：

### LMB_TEST/ - 详细硬件接口调试经验
- `README.md`：涵盖USB、HDMI、WiFi/蓝牙、UART、以太网、PCIE、IMU等接口调试
- `imuTest/get_imu.py`：IMU传感器数据采集与解析脚本
- `patch/`、`autoCheck/`、`scripts/`：补丁、自动检测、常用脚本

### EVB_TEST/ - RK3588开发板验证经验
- `RK3588 EVB7-V11 调试与功能验证总结.md`：完整的开发板调试指南
- `editFiles/`：设备树(dtsi)、驱动(c文件)等源码修改示例

### gpio_name2num.py - GPIO转换工具
传统Python版本的GPIO名称编号转换工具，现已整合到新框架中。

## 🤝 贡献指南

欢迎贡献代码和建议！

### 贡献方式
1. Fork 项目
2. 创建功能分支
3. 提交代码
4. 发起 Pull Request

### 代码规范
- 遵循现有代码风格
- 添加必要的注释
- 包含错误处理
- 提供使用示例

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 📞 联系方式

- **作者**: a869320750
- **项目地址**: https://github.com/a869320750/HWTest
- **问题反馈**: [Issues](https://github.com/a869320750/HWTest/issues)

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给个Star支持一下！**

Made with ❤️ for 嵌入式开发者

</div>
