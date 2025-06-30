1. 查看所有硬件信息
```sh
lspci -nn
lsusb
lshw
```
lspci：列出所有PCI设备（如网卡、显卡等）。
lsusb：列出所有USB设备。
lshw：列出详细硬件信息（需root权限）。
2. 查看驱动加载情况
```sh
lspci -nn
lsusb
lshw
```
lsmod：显示已加载的内核模块（驱动）。
dmesg：查看内核日志，过滤fail/error可查找驱动加载失败信息。
3. 检查未识别设备
```sh
lspci -nn
lsusb
lshw
```
查找内核日志中“unknown device”“not found”等提示，通常是驱动未加载或硬件未识别。
4. 检查设备节点
```sh
ls /dev
```
检查对应硬件的设备节点是否存在（如/dev/ttyUSB*、/dev/net/*等）。

5. 其他工具
lspci -k：可以直接看到每个PCI设备当前使用的驱动（或未绑定驱动）。
hwinfo（部分系统需安装）：hwinfo --short。

总结：

lspci -k、lsusb、lsmod、dmesg 是最常用的组合。
发现有设备没有驱动时，可以根据lspci或lsusb输出的厂商ID、设备ID去查找对应驱动。


总结表
```
接口	通用性	是否需要原厂驱动/适配
WIFI/BT	低	需要原厂驱动和固件
SD卡	较高	通用为主，特殊情况需原厂
ES8388 codec	中等	主线有驱动，板级适配需原厂
mipi OLED	低	需要原厂驱动和参数适配
mipi CSI camera	低	需要原厂驱动/适配	摄像头sensor、mipi控制器、ISP等都需原厂适配，主线很少通用
USB HUB	高	通用	标准USB HUB芯片，Linux内核自带驱动，基本即插即用
PCIE转MDI功能	低~中	视芯片而定，常需原厂驱动	MDI（以太网PHY）如非主流芯片需原厂，主流网卡可通用
1DI HUB功能	低	需原厂说明	“1DI HUB”不常见，需明确芯片/协议，通常需原厂
PCIE1: 4G/5G	低~中	多数需原厂驱动/固件	4G/5G模块（如Quectel、Fibocom等）需原厂驱动/固件/拨号脚本
PCIE2: 卫通功能	低	需原厂驱动/协议	卫星通信模块多为专用，需原厂
PCIE3: RTK功能	低~中	多数需原厂驱动/协议	RTK模块（高精度定位）多为专用，需原厂
FCIE4: 自组网功能	低	需原厂驱动/协议	“自组网”多为专用无线模块，需原厂
M2-1 NVME固态硬盘	高	通用	标准NVMe协议，Linux内核自带驱动
M2-2 4G/5G	低~中	多数需原厂驱动/固件	同上，4G/5G模块需原厂
TYPEC 频谱扫频功能	低	需原厂驱动/协议	专用频谱仪/扫频设备，需原厂
```

总结
```
USB HUB、NVMe固态硬盘：通用，Linux内核自带驱动。
4G/5G、卫通、RTK、自组网、频谱扫频、mipi摄像头：绝大多数都需要原厂驱动、固件、协议文档和适配。
PCIE转MDI、1DI HUB：需明确芯片型号，主流网卡可通用，非主流或专用芯片需原厂。
```

1. 驱动获取途径补充
建议在每类硬件后面补充“驱动获取途径”：
```
内核自带驱动：直接用现有内核，或升级内核即可（如USB HUB、NVMe）。
板卡原厂/芯片原厂驱动：联系板卡厂商或芯片原厂获取（如WIFI/BT、4G/5G、MIPI摄像头等）。
开源社区：部分主流芯片可在GitHub、kernel.org等社区找到第三方驱动。
内核编译：部分驱动需在内核配置（make menuconfig）中选中并重新编译。
```

2. 验证方法补充
建议每个接口后面加一行“验证方法/命令”：
```
WIFI/BT
驱动加载：lsmod | grep wifi、dmesg | grep -i wifi
设备识别：iwconfig、ifconfig -a、hciconfig（蓝牙）
扫描网络：iwlist scan
SD卡
设备节点：ls /dev/mmc*
挂载测试：mount /dev/mmcblk0p1 /mnt
ES8388 codec
驱动加载：lsmod | grep es8388
声卡识别：aplay -l、arecord -l
mipi OLED/CSI camera
设备节点：ls /dev/fb*（OLED）、ls /dev/video*（摄像头）
测试工具：mplayer tv://、v4l2-ctl --list-devices
USB HUB
设备识别：lsusb、插拔U盘测试
PCIE转MDI/网卡
设备识别：lspci -nn | grep Eth
网络测试：ifconfig -a、ethtool eth0
4G/5G模块
设备节点：ls /dev/ttyUSB*、lsusb
拨号测试：mmcli、minicom
NVMe固态硬盘
设备识别：lsblk、fdisk -l、nvme list
TYPEC 频谱扫频
需原厂工具或协议，通常有专用命令或上位机软件
```

3. 驱动编译/加载流程补充
```
内核模块驱动：
编译：make menuconfig 选中对应模块，make、make modules_install
加载：insmod xxx.ko 或 modprobe xxx
卸载：rmmod xxx
固件文件：
通常放在 /lib/firmware/ 目录，驱动加载时自动读取
```