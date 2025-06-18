import re

def gpio_name_to_bank_pin_num(gpio_name):
    m = re.match(r'GPIO(\d+)_([A-H])(\d)', gpio_name.upper())
    if not m:
        raise ValueError(f"格式不正确: {gpio_name}")
    bank = int(m.group(1))
    letter = m.group(2)
    num = int(m.group(3))
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
    return f"""    {label}: {gpio_name.lower().replace('_', '-')}-out {{
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

if __name__ == "__main__":
    # 示例配置
    gpio_cfgs = [
        ("GPIO4_B5_D", "down", "high"),
        ("GPIO4_B4_U", "up", "high"),
        ("GPIO1_B2_D", "down", "high"),
        # ("GPIO1_A7_U", "up", "high"),
        # ("GPIO1_A6_D", "down", "high"),
        ("GPIO2_C5_D", "down", "high"),
        ("GPIO2_B1_U", "up", "low"),
    ]

    print("// GPIO编号对照表")
    for name, pull, level in gpio_cfgs:
        _, _, num = gpio_name_to_bank_pin_num(name)
        print(f"{name}: {num}")

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