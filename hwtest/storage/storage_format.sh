#!/bin/bash
# filepath: storage_format.sh
# 存储设备格式化工具 - 带多重安全保护

show_usage() {
    echo "用法: hwtest storage format [选项]"
    echo ""
    echo "⚠️  警告: 格式化操作会永久删除数据！"
    echo ""
    echo "选项:"
    echo "  -l, --list           仅列出可格式化的设备(推荐)"
    echo "  -d, --device <dev>   指定设备(需要完整路径)"
    echo "  -t, --type <fs>      文件系统类型(ext4/fat32/ntfs)"
    echo "  -f, --force          强制格式化(跳过确认)"
    echo "  --dry-run            仅显示将执行的命令"
    echo "  --help               显示帮助"
    echo ""
    echo "安全提示:"
    echo "  • 仅支持可移动设备(SD卡、U盘等)"
    echo "  • 不支持系统盘和重要分区"
    echo "  • 操作前会多次确认"
    echo ""
    echo "示例:"
    echo "  hwtest storage format --list        # 列出可格式化设备"
    echo "  hwtest storage format --dry-run -d /dev/sdb1  # 预览操作"
}

# 检查设备是否可以安全格式化
is_safe_to_format() {
    local device="$1"
    
    # 检查是否是系统关键分区
    local forbidden_patterns=(
        "/"
        "/boot"
        "/usr"
        "/var"
        "/home"
        "swap"
    )
    
    for pattern in "${forbidden_patterns[@]}"; do
        if mount | grep -q "$device.*$pattern"; then
            echo "❌ 危险: $device 挂载在系统关键位置 $pattern"
            return 1
        fi
    done
    
    # 检查是否是可移动设备
    local device_base=$(echo "$device" | sed 's/[0-9]*$//')
    if [[ -f "/sys/block/$(basename $device_base)/removable" ]]; then
        local removable=$(cat "/sys/block/$(basename $device_base)/removable" 2>/dev/null)
        if [[ "$removable" == "1" ]]; then
            echo "✅ 可移动设备，相对安全"
            return 0
        fi
    fi
    
    echo "⚠️  警告: $device 不是可移动设备，需要额外确认"
    return 2
}

# 列出可格式化的设备
list_formattable_devices() {
    echo "=========================================="
    echo "可格式化的存储设备列表"
    echo "=========================================="
    
    # 查找可移动设备
    echo "🔍 扫描可移动设备..."
    local found_devices=0
    
    for dev in /dev/sd* /dev/mmcblk* /dev/nvme*; do
        if [[ -b "$dev" ]]; then
            local device_name=$(basename "$dev")
            local removable_file="/sys/block/${device_name%p*}/removable"
            
            if [[ -f "$removable_file" ]]; then
                local removable=$(cat "$removable_file" 2>/dev/null)
                if [[ "$removable" == "1" ]]; then
                    local size=$(lsblk -nd -o SIZE "$dev" 2>/dev/null)
                    local model=$(lsblk -nd -o MODEL "$dev" 2>/dev/null)
                    local fstype=$(lsblk -nd -o FSTYPE "$dev" 2>/dev/null)
                    
                    echo "📱 设备: $dev"
                    echo "   大小: $size"
                    echo "   型号: $model"
                    echo "   文件系统: ${fstype:-未知}"
                    echo "   状态: ✅ 安全可格式化"
                    echo ""
                    ((found_devices++))
                fi
            fi
        fi
    done
    
    if [[ $found_devices -eq 0 ]]; then
        echo "❌ 未发现可安全格式化的设备"
        echo ""
        echo "💡 提示:"
        echo "   • 请插入SD卡或U盘"
        echo "   • 系统磁盘不会显示在此列表中"
    else
        echo "⚠️  重要提示:"
        echo "   • 格式化会永久删除所有数据"
        echo "   • 请确保已备份重要文件"
        echo "   • 建议使用 --dry-run 预览操作"
    fi
    
    echo "=========================================="
}

# 预览格式化操作
preview_format() {
    local device="$1"
    local fstype="$2"
    
    echo "=========================================="
    echo "格式化操作预览"
    echo "=========================================="
    echo "目标设备: $device"
    echo "文件系统: $fstype"
    echo ""
    echo "将执行的命令:"
    
    case "$fstype" in
        "ext4")
            echo "  mkfs.ext4 -F \"$device\""
            ;;
        "fat32")
            echo "  mkfs.fat -F32 \"$device\""
            ;;
        "ntfs")
            echo "  mkfs.ntfs -f \"$device\""
            ;;
        *)
            echo "  不支持的文件系统: $fstype"
            return 1
            ;;
    esac
    
    echo ""
    echo "⚠️  这只是预览，未执行实际操作"
    echo "=========================================="
}

# 默认参数
LIST_ONLY=false
DEVICE=""
FSTYPE="ext4"
FORCE=false
DRY_RUN=false

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list)
            LIST_ONLY=true
            shift
            ;;
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -t|--type)
            FSTYPE="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "❌ 错误: 格式化操作需要root权限"
    echo "请使用: sudo hwtest storage format"
    exit 1
fi

# 列出设备模式
if [[ "$LIST_ONLY" == "true" ]]; then
    list_formattable_devices
    exit 0
fi

# 如果没有指定设备，显示列表并退出
if [[ -z "$DEVICE" ]]; then
    echo "❌ 错误: 未指定设备"
    echo ""
    list_formattable_devices
    echo ""
    echo "💡 使用 -d 参数指定设备，或使用 --list 查看可用设备"
    exit 1
fi

# 检查设备是否存在
if [[ ! -b "$DEVICE" ]]; then
    echo "❌ 错误: 设备 $DEVICE 不存在或不是块设备"
    exit 1
fi

# 安全检查
echo "🔍 正在进行安全检查..."
safe_result=$(is_safe_to_format "$DEVICE")
safe_status=$?

case $safe_status in
    1)
        echo "$safe_result"
        echo "❌ 拒绝格式化系统关键分区"
        exit 1
        ;;
    2)
        echo "$safe_result"
        if [[ "$FORCE" != "true" ]]; then
            echo "❌ 为了安全，请使用 --force 参数强制格式化非可移动设备"
            exit 1
        fi
        ;;
    0)
        echo "$safe_result"
        ;;
esac

# 预览模式
if [[ "$DRY_RUN" == "true" ]]; then
    preview_format "$DEVICE" "$FSTYPE"
    exit 0
fi

# 最终确认
if [[ "$FORCE" != "true" ]]; then
    echo ""
    echo "⚠️  最终确认"
    echo "=========================================="
    echo "设备: $DEVICE"
    echo "文件系统: $FSTYPE"
    echo ""
    echo "❗ 此操作将永久删除设备上的所有数据！"
    echo ""
    read -p "确认格式化？输入 'YES' 继续: " confirmation
    
    if [[ "$confirmation" != "YES" ]]; then
        echo "❌ 操作已取消"
        exit 1
    fi
fi

echo "🚀 开始格式化 $DEVICE..."
echo "❗ 请勿断开设备或中断操作"

# 执行格式化
case "$FSTYPE" in
    "ext4")
        if mkfs.ext4 -F "$DEVICE"; then
            echo "✅ 格式化完成"
        else
            echo "❌ 格式化失败"
            exit 1
        fi
        ;;
    "fat32")
        if mkfs.fat -F32 "$DEVICE"; then
            echo "✅ 格式化完成"
        else
            echo "❌ 格式化失败"
            exit 1
        fi
        ;;
    "ntfs")
        if mkfs.ntfs -f "$DEVICE"; then
            echo "✅ 格式化完成"
        else
            echo "❌ 格式化失败"
            exit 1
        fi
        ;;
    *)
        echo "❌ 不支持的文件系统: $FSTYPE"
        exit 1
        ;;
esac

echo "=========================================="
