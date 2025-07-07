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

def gen_pinctrl_block(gpio_name, pull="none"):
    bank, pin, _ = gpio_name_to_bank_pin_num(gpio_name)
    pull_map = {
        "up": "&pcfg_pull_up",
        "down": "&pcfg_pull_down",
        "none": "&pcfg_pull_none"
    }
    pull_cfg = pull_map.get(pull, "&pcfg_pull_none")
    label = gpio_name.lower() + "_out"
    return f"""        {label}: {gpio_name.lower().replace('_', '-')}-out {{
            rockchip,pins = <{bank} {pin} RK_FUNC_GPIO {pull_cfg}>;
        }};"""

def gen_regulator_block(gpio_name, level="high"):
    bank, pin, _ = gpio_name_to_bank_pin_num(gpio_name)
    label = gpio_name.lower() + "_reg"
    reg_name = gpio_name.lower()
    active = "enable-active-high" if level == "high" else "enable-active-low"
    pinctrl_label = gpio_name.lower() + "_out"
    return f"""{label}: {gpio_name.lower().replace('_', '-')}-regulator {{
    compatible = "regulator-fixed";
    regulator-name = "{reg_name}";
    regulator-boot-on;
    regulator-always-on;
    {active};
    gpio = <&gpio{bank} {pin} GPIO_ACTIVE_HIGH>;
    pinctrl-names = "default";
    pinctrl-0 = <&{pinctrl_label}>;
}};"""

def gpio_name_to_sysfs_num(gpio_name):
    _, _, gpio_num = gpio_name_to_bank_pin_num(gpio_name)
    return gpio_num

if __name__ == "__main__":
    # 示例配置
    gpio_cfgs = [
        # ("GPIO3_D5_D", "down", "high"),
        # ("GPIO3_D2_D", "down", "high"),
        # ("GPIO1_B3_D", "down", "high"),
        # ("GPIO3_D3_D", "down", "high"),
        # ("GPIO3_C7_U", "up", "high"),
        # ("GPIO0_C6_U", "up", "high"),
        # ("GPIO0_C5_U", "up", "high"),
        # ("GPIO4_A1_D", "down", "high"),
        # ("GPIO0_C4_D", "down", "high"),
        ("GPIO0_A7_U", "up", "high"),
        ("GPIO1_B6_U", "up", "high"),
        ("GPIO1_B7_U", "up", "high"),
        ("GPIO3_D2_D", "down", "high"),
        ("GPIO4_B6_D", "down", "high"),
        ("GPIO3_D3_D", "down", "high"),
        
    ]

    print("// GPIO编号对照表")
    for name, pull, level in gpio_cfgs:
        print(f"{name}: {gpio_name_to_sysfs_num(name)}")

    print("\n// pinctrl 配置片段")
    print("&pinctrl {")
    print("    custom_gpio_cfg {")
    for name, pull, _ in gpio_cfgs:
        print(gen_pinctrl_block(name, pull))
    print("    };")
    print("};\n")

    print("// regulator-fixed 配置片段")
    print("/ {")
    for name, _, level in gpio_cfgs:
        print(gen_regulator_block(name, level))
    print("};")

    # 自动生成sysfs GPIO配置命令
    print("# 自动生成的GPIO配置命令")
    for name, direction, value in [
        ("GPIO0_A7_U", "out", 1),
        ("GPIO1_B6_U", "out", 1),
        ("GPIO1_B7_U", "out", 1),
        ("GPIO3_D2_D", "out", 1),
        ("GPIO4_B6_D", "out", 1),
        ("GPIO3_D3_D", "out", 1),
        
    ]:
        gpio = gpio_name_to_sysfs_num(name)
        print(f"echo {gpio} > /sys/class/gpio/export")
        print(f"echo {direction} > /sys/class/gpio/gpio{gpio}/direction")
        if direction == "out" and value is not None:
            print(f"echo {value} > /sys/class/gpio/gpio{gpio}/value")
    print("# 可将以上命令复制到开发板执行")