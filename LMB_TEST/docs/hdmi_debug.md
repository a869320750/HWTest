# 2. HDMI输出与分辨率切换

本节介绍嵌入式平台常见的HDMI输出测试方法、分辨率切换工具及常用调试命令，适用于开发板、工控机等场景。

## 2.1 功能简介
- HDMI接口用于连接显示器、电视等外部显示设备，实现视频输出。
- 常见需求包括：
  - 检查HDMI是否正常输出画面
  - 切换分辨率、刷新率
  - 验证多种显示模式兼容性

## 2.2 常用工具
- `xrandr`：X11环境下常用的显示管理工具，可查询和切换分辨率。
- `modetest`：DRM/KMS环境下的命令行测试工具，适合无桌面环境的嵌入式Linux。
- `dmesg`：查看内核HDMI相关日志。

## 2.3 常用命令
- 查询当前分辨率/显示输出：
  - `xrandr`
  - `modetest -c`  # 查看所有输出和分辨率
- 切换分辨率：
  - `xrandr --output HDMI-1 --mode 1920x1080`
  - `modetest -s <connector_id>:1920x1080`
- 查看HDMI相关内核日志：
  - `dmesg | grep -i hdmi`

---

## 附录：HDMI一键检测脚本

> 说明：本脚本可一键收集HDMI输出、分辨率、内核日志等信息，便于整体排查。请复制到板子上执行。

```sh
#!/bin/sh

echo "===== 1. xrandr显示输出（如有X11环境） ====="
xrandr 2>/dev/null

echo "\n===== 2. modetest输出（如有modetest工具） ====="
modetest -c 2>/dev/null

# 自动检测第一个HDMI输出并尝试切换分辨率
# 仅供参考，实际环境请根据输出名称调整
if command -v xrandr >/dev/null; then
  HDMI_OUT=$(xrandr | grep -Eo '^HDMI-[0-9]')
  if [ -n "$HDMI_OUT" ]; then
    echo "\n===== 3. 尝试切换 $HDMI_OUT 到 1920x1080 ====="
    xrandr --output $HDMI_OUT --mode 1920x1080 2>/dev/null
  fi
fi

echo "\n===== 4. dmesg HDMI相关日志 ====="
dmesg | grep -i hdmi | tail -n 50

echo "\n===== 检查完成，请结合回显分析HDMI输出情况 ====="
```

> 如需定制检测内容（如指定分辨率、特定HDMI端口等），可在脚本中补充相应命令。
