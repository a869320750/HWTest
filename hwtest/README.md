# hwtest 一键硬件自检工具

`hwtest` 是针对嵌入式平台（如RK3588等）开发的纯Shell一键硬件功能检测工具，适用于出厂批量测试、现场维护、远程诊断等场景。

## 主要特性
- 支持 WiFi、蓝牙、以太网、USB、音频、GPIO、PCIe 等多项功能一键检测
- 每项功能均有独立检测脚本，便于扩展和维护
- 自动生成详细日志和检测报告，便于问题追溯
- 纯Shell实现，无需额外依赖，平台兼容性强

## 快速使用

1. **复制 hwtest 目录到目标板子**
   ```bash
   cp -r ./hwtest ~/hwtest
   cd ~/hwtest
   ```
2. **转换为Unix格式（如从Windows拷贝）**
   ```bash
   sudo apt-get install dos2unix   # 如未安装
   dos2unix *.sh

   # 或者用sed转换
   sed -i 's/\r$//' ~/hwtest/*.sh
   ```
3. **赋予可执行权限**
   ```bash
   chmod +x *.sh
   ```
4. **建立软连接到PATH（推荐）**
   ```bash
   sudo ln -sf ~/hwtest/main_test.sh /usr/local/bin/hwtest
   ```
5. **运行命令**
   ```bash
   hwtest --help         # 查看用法
   hwtest all            # 一键全功能检测
   hwtest wifi           # 单项检测
   ```

## 检测结果说明
- 日志保存在 `/tmp/hw_test_logs/`，报告保存在 `/tmp/hw_test_report.txt`
- 每项检测脚本输出“测试成功/测试失败”关键字，主控脚本自动判定

## 常见问题
- **bad interpreter: No such file or directory**
  - 说明脚本为Windows格式，需用`dos2unix`转换为Unix格式
- **测试脚本不存在**
  - 请确认所有 *_test.sh 脚本均在 hwtest 目录下，且有执行权限

---
如需扩展新功能，只需新增对应的 xxx_test.sh 并在 main_test.sh 的 TESTS 数组中添加即可。
