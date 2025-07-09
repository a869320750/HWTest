# 8. PCIE接口与自组网模块调试

## 8. PCIE接口配置与自组网模块调试
- 当前状况分析
- PCIE基础检查
- 自组网模块识别与驱动
- 网络接口配置
- 调试步骤优先级
- 潜在问题排查
- nvme硬盘测试

...（详细命令、脚本、经验可补充）

```bash
dmesg | grep pci

lsblk

fdisk -l

dmesg | grep -i nvme

 ls /dev/nvme*


dd if=/dev/zero of=/dev/nvme0n1 bs=1M count=10 oflag=direct
dd if=/dev/nvme0n1 of=/dev/null bs=1M count=10 iflag=direct
```