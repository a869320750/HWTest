#!/bin/bash
# 发布 HWTest 脚本到 buildroot overlay

SRC_DIR="/mnt/d/Codes/HWTest/hwtest"
OVERLAY_DIR="/home/jinyingjiejinyingjie/rk3588_sdk/rk3588_linux_default_20250120/buildroot/board/rockchip/rk3588/fs-overlay"

# 创建目标目录
mkdir -p "$OVERLAY_DIR/usr/local/bin/hw_test"

#!/bin/bash
# 发布 HWTest 脚本到 buildroot overlay

SRC_DIR="/mnt/d/Codes/HWTest/hwtest"
OVERLAY_DIR="/home/jinyingjiejinyingjie/rk3588_sdk/rk3588_linux_default_20250120/buildroot/board/rockchip/rk3588/fs-overlay"

# 创建目标目录
mkdir -p "$OVERLAY_DIR/usr/local/bin/hw_test"

echo "开始发布hwtest工具..."

# 拷贝主脚本和测试脚本
echo "复制主要文件..."
cp "$SRC_DIR/main_test.sh" "$OVERLAY_DIR/usr/local/bin/hw_test/"
cp "$SRC_DIR"/*_test.sh "$OVERLAY_DIR/usr/local/bin/hw_test/" 2>/dev/null || true

# 拷贝子目录
echo "复制子目录..."
for subdir in uart gpio storage monitor tools; do
    if [[ -d "$SRC_DIR/$subdir" ]]; then
        echo "  复制 $subdir/ 目录..."
        cp -r "$SRC_DIR/$subdir" "$OVERLAY_DIR/usr/local/bin/hw_test/"
    fi
done

# 主入口脚本重命名为 hwtest 并放到 /usr/local/bin
cp "$SRC_DIR/main_test.sh" "$OVERLAY_DIR/usr/local/bin/hwtest"

# 转换为Unix格式
echo "转换文件格式..."
dos2unix "$OVERLAY_DIR/usr/local/bin/hwtest" 2>/dev/null || true
find "$OVERLAY_DIR/usr/local/bin/hw_test" -name "*.sh" -exec dos2unix {} \; 2>/dev/null || true

# 赋予可执行权限
echo "设置执行权限..."
chmod +x "$OVERLAY_DIR/usr/local/bin/hwtest"
find "$OVERLAY_DIR/usr/local/bin/hw_test" -name "*.sh" -exec chmod +x {} \;

# 自动添加 /usr/local/bin 到 PATH
mkdir -p "$OVERLAY_DIR/etc/profile.d"
echo 'export PATH=$PATH:/usr/local/bin' > "$OVERLAY_DIR/etc/profile.d/hwtest_path.sh"
chmod +x "$OVERLAY_DIR/etc/profile.d/hwtest_path.sh"

echo "发布完成！"
echo "发布内容:"
echo "  - 主程序: /usr/local/bin/hwtest"
echo "  - 工具集: /usr/local/bin/hw_test/"
find "$OVERLAY_DIR/usr/local/bin/hw_test" -name "*.sh" | sed 's|.*/|    - |'

# 自动添加 /usr/local/bin 到 PATH
mkdir -p "$OVERLAY_DIR/etc/profile.d"
echo 'export PATH=$PATH:/usr/local/bin' > "$OVERLAY_DIR/etc/profile.d/hwtest_path.sh"
chmod +x "$OVERLAY_DIR/etc/profile.d/hwtest_path.sh"

echo "发布完成！"