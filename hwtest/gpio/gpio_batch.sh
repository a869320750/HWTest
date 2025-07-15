#!/bin/bash
# filepath: gpio_batch.sh  
# GPIO批量操作工具

show_usage() {
    echo "用法: hwtest gpio batch [选项] <配置文件>"
    echo ""
    echo "批量GPIO操作工具，支持配置文件和脚本模式"
    echo ""
    echo "选项:"
    echo "  -f, --file <文件>    GPIO配置文件"
    echo "  -g, --generate       生成配置文件模板"
    echo "  -v, --verify         操作后验证"
    echo "  -d, --delay <ms>     操作间延迟"
    echo "  --help               显示帮助"
    echo ""
    echo "配置文件格式:"
    echo "  # GPIO配置文件"
    echo "  # 格式: GPIO名称或编号:方向:值:描述"
    echo "  GPIO3_D2_D:out:1:LED控制"
    echo "  125:out:0:电源控制"
    echo "  GPIO0_A5_U:in::按键检测"
    echo ""
    echo "示例:"
    echo "  hwtest gpio batch --generate > gpio_config.txt"
    echo "  hwtest gpio batch -f gpio_config.txt"
}

# 生成配置文件模板
generate_template() {
    cat << 'EOF'
# GPIO批量配置文件模板
# 格式: GPIO名称或编号:方向:值:描述
# 
# 示例配置:

# LED控制组
GPIO3_D2_D:out:1:红色LED
GPIO3_D3_D:out:0:绿色LED
GPIO3_D4_D:out:1:蓝色LED

# 电源控制组  
GPIO4_A0_U:out:1:主电源开关
GPIO4_A1_U:out:0:外设电源

# 输入检测组
GPIO0_A5_U:in::按键1检测
GPIO0_A6_U:in::按键2检测

# 数字编号方式
125:out:1:调试LED
126:in::状态检测

# 注意:
# - 方向: in(输入) 或 out(输出)
# - 值: 0(低电平) 或 1(高电平)，输入模式可留空
# - 描述: 可选的功能说明
EOF
}

# 解析配置行
parse_config_line() {
    local line="$1"
    
    # 跳过注释和空行
    if [[ "$line" =~ ^[[:space:]]*# || -z "$line" ]]; then
        return 1
    fi
    
    # 解析格式: GPIO:direction:value:description
    IFS=':' read -r gpio_input direction value description <<< "$line"
    
    # 去除空格
    gpio_input=$(echo "$gpio_input" | xargs)
    direction=$(echo "$direction" | xargs)
    value=$(echo "$value" | xargs)
    description=$(echo "$description" | xargs)
    
    # 验证必要字段
    if [[ -z "$gpio_input" || -z "$direction" ]]; then
        echo "❌ 配置错误: $line"
        return 1
    fi
    
    # 输出解析结果
    echo "$gpio_input|$direction|$value|$description"
    return 0
}

# 批量执行GPIO操作
batch_execute() {
    local config_file="$1"
    local verify="$2"
    local delay="$3"
    
    if [[ ! -f "$config_file" ]]; then
        echo "❌ 配置文件不存在: $config_file"
        return 1
    fi
    
    echo "=========================================="
    echo "批量GPIO操作执行"
    echo "配置文件: $config_file"
    echo "=========================================="
    
    local total=0
    local success=0
    local failed=0
    
    while IFS= read -r line; do
        local parsed=$(parse_config_line "$line")
        if [[ $? -eq 0 ]]; then
            ((total++))
            
            IFS='|' read -r gpio_input direction value description <<< "$parsed"
            
            echo ""
            echo "[$total] 操作GPIO: $gpio_input"
            if [[ -n "$description" ]]; then
                echo "    描述: $description"
            fi
            
            # 导出GPIO
            if ! hwtest gpio export "$gpio_input" -d "$direction" ${value:+-v "$value"} >/dev/null 2>&1; then
                echo "    ❌ 失败"
                ((failed++))
            else
                echo "    ✅ 成功 (方向: $direction${value:+, 值: $value})"
                ((success++))
                
                # 验证操作
                if [[ "$verify" == "true" && -n "$value" ]]; then
                    sleep 0.1  # 短暂等待
                    local actual=$(hwtest gpio get "$gpio_input" 2>/dev/null | grep -o '[01]' | head -1)
                    if [[ "$actual" == "$value" ]]; then
                        echo "    ✓ 验证通过"
                    else
                        echo "    ⚠ 验证失败: 期望=$value, 实际=$actual"
                    fi
                fi
            fi
            
            # 操作间延迟
            if [[ -n "$delay" && $delay -gt 0 ]]; then
                sleep $(echo "scale=3; $delay/1000" | bc -l)
            fi
        fi
    done < "$config_file"
    
    echo ""
    echo "=========================================="
    echo "批量操作完成"
    echo "总计: $total"
    echo "成功: $success"  
    echo "失败: $failed"
    echo "成功率: $(( success * 100 / total ))%"
    echo "=========================================="
    
    return $failed
}

# 默认参数
CONFIG_FILE=""
GENERATE=false
VERIFY=false
DELAY=0

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -g|--generate)
            GENERATE=true
            shift
            ;;
        -v|--verify)
            VERIFY=true
            shift
            ;;
        -d|--delay)
            DELAY="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$CONFIG_FILE" ]]; then
                CONFIG_FILE="$1"
            else
                echo "未知参数: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# 生成模板
if [[ "$GENERATE" == "true" ]]; then
    generate_template
    exit 0
fi

# 检查配置文件
if [[ -z "$CONFIG_FILE" ]]; then
    echo "❌ 错误: 请指定配置文件"
    echo ""
    echo "💡 提示:"
    echo "  hwtest gpio batch --generate > config.txt  # 生成模板"
    echo "  hwtest gpio batch -f config.txt            # 执行配置"
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "⚠️ 警告: 建议以root权限运行"
    echo ""
fi

# 执行批量操作
batch_execute "$CONFIG_FILE" "$VERIFY" "$DELAY"
