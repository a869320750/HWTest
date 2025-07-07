# 本脚本用于将 Rockchip 平台的 GPIO 名称（如 GPIO3_D2_D）自动转换为 bank/pin/sysfs编号，
# 并自动生成设备树 pinctrl/regulator 片段及 sysfs 配置命令，辅助硬件调试和驱动开发。
# 算法说明：
#   - GPIO 名称格式为 GPIOx_AY_U/D，其中 x 为 bank 号，A-H 为组，Y 为组内编号，U/D 表示上/下拉
#   - pin = (组字母序号) * 8 + Y
#   - sysfs编号 = bank * 32 + pin
#   - pull 类型自动从名称后缀 _U/_D 解析

import re

def gpio_name_to_bank_pin_num(gpio_name):
    """
    支持 GPIOx_AY_U/D 格式，返回 (bank, pin, gpio_num)
    bank: DTS里的bank号
    pin: DTS里的pin号
    gpio_num: sysfs编号
    """
    m = re.match(r'GPIO(\d+)_([A-H])(\d)_([UD])', gpio_name.upper())
    if not m:
        raise ValueError(f"格式不正确: {gpio_name}")
    bank = int(m.group(1))
    letter = m.group(2)
    num = int(m.group(3))
    # Rockchip: A=0, B=1, ... H=7
    letter_idx = ord(letter) - ord('A')
    pin = letter_idx * 8 + num
    gpio_num = bank * 32 + pin
    return bank, pin, gpio_num

def parse_pull_from_name(gpio_name):
    """根据名称后缀自动解析pull类型"""
    m = re.match(r'.*_([UD])$', gpio_name.upper())
    if not m:
        return "none"
    return "up" if m.group(1) == "U" else "down"

def gen_pinctrl_block(gpio_name):
    bank, pin, _ = gpio_name_to_bank_pin_num(gpio_name)
    pull = parse_pull_from_name(gpio_name)
    pull_map = {
        "up": "&pcfg_pull_up",
        "down": "&pcfg_pull_down",
        "none": "&pcfg_pull_none"
    }
    pull_cfg = pull_map.get(pull, "&pcfg_pull_none")
    label = gpio_name.lower() + "_out"
    return f"""        {label}: {gpio_name.lower().replace('_', '-')}-out {{\n            rockchip,pins = <{bank} {pin} RK_FUNC_GPIO {pull_cfg}>;\n        }};"""

def gen_regulator_block(gpio_name, level="high"):
    bank, pin, _ = gpio_name_to_bank_pin_num(gpio_name)
    label = gpio_name.lower() + "_reg"
    reg_name = gpio_name.lower()
    active = "enable-active-high" if level == "high" else "enable-active-low"
    pinctrl_label = gpio_name.lower() + "_out"
    return f"""{label}: {gpio_name.lower().replace('_', '-')}-regulator {{\n    compatible = \"regulator-fixed\";\n    regulator-name = \"{reg_name}\";\n    regulator-boot-on;\n    regulator-always-on;\n    {active};\n    gpio = <&gpio{bank} {pin} GPIO_ACTIVE_HIGH>;\n    pinctrl-names = \"default\";\n    pinctrl-0 = <&{pinctrl_label}>;\n}};"""

def gpio_name_to_sysfs_num(gpio_name):
    _, _, gpio_num = gpio_name_to_bank_pin_num(gpio_name)
    return gpio_num

if __name__ == "__main__":
    # 简化后的配置：只需名称和电平
    gpio_cfgs = [
        ("GPIO0_A7_U", "high"),
        ("GPIO1_B6_U", "high"),
        ("GPIO1_B7_U", "high"),
        ("GPIO3_D2_D", "high"),
        ("GPIO4_B6_D", "high"),
        ("GPIO3_D3_D", "high"),
    ]

    print("// GPIO编号对照表")
    for name, _ in gpio_cfgs:
        print(f"{name}: {gpio_name_to_sysfs_num(name)}")

    print("\n// pinctrl 配置片段")
    print("&pinctrl {")
    print("    custom_gpio_cfg {")
    for name, _ in gpio_cfgs:
        print(gen_pinctrl_block(name))
    print("    };")
    print("};\n")

    print("// regulator-fixed 配置片段")
    print("/ {")
    for name, level in gpio_cfgs:
        print(gen_regulator_block(name, level))
    print("};")

    # 自动生成sysfs GPIO配置命令
    print("# 自动生成的GPIO配置命令")
    for name, level in gpio_cfgs:
        gpio = gpio_name_to_sysfs_num(name)
        print(f"echo {gpio} > /sys/class/gpio/export")
        print(f"echo out > /sys/class/gpio/gpio{gpio}/direction")
        if level == "high":
            print(f"echo 1 > /sys/class/gpio/gpio{gpio}/value")
        elif level == "low":
            print(f"echo 0 > /sys/class/gpio/gpio{gpio}/value")
    print("# 可将以上命令复制到开发板执行")