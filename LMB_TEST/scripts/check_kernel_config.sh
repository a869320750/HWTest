#!/bin/sh
# filepath: check_kernel_config.sh

CONFIG_FILE=${1:-/boot/config-$(uname -r)}

echo "检查内核配置文件: $CONFIG_FILE"
echo

CONFIGS="
CONFIG_MMC_DW_ROCKCHIP=y
CONFIG_WIRELESS=y
CONFIG_WIRELESS_EXT=y
CONFIG_WEXT_CORE=y
CONFIG_WEXT_PROC=y
CONFIG_WEXT_PRIV=y
CONFIG_CFG80211=y
CONFIG_CFG80211_REQUIRE_SIGNED_REGDB=y
CONFIG_CFG80211_USE_KERNEL_REGDB_KEYS=y
CONFIG_CFG80211_DEFAULT_PS=y
CONFIG_CFG80211_CRDA_SUPPORT=y
# CONFIG_CFG80211_WEXT is not set
CONFIG_MAC80211=y
CONFIG_MAC80211_HAS_RC=y
CONFIG_MAC80211_RC_MINSTREL=y
CONFIG_MAC80211_RC_DEFAULT_MINSTREL=y
CONFIG_MAC80211_RC_DEFAULT=\"minstrel_ht\"
CONFIG_MAC80211_STA_HASH_MAX_SIZE=0
CONFIG_RFKILL=y
CONFIG_RFKILL_RK=y
CONFIG_MMC=y
CONFIG_PWRSEQ_SIMPLE=y
CONFIG_MMC_DW=y
CONFIG_MMC_DW_PLTFM=y
"

for line in $CONFIGS; do
    # 跳过注释
    echo "$line" | grep -q '^#' && continue
    key=$(echo "$line" | cut -d= -f1)
    val=$(echo "$line" | cut -d= -f2-)
    grep -q "^$key=$val" "$CONFIG_FILE"
    if [ $? -eq 0 ]; then
        echo "✔ $key=$val"
    else
        echo "✘ $key=$val (未找到或未设置)"
    fi
done

# 检查 # CONFIG_CFG80211_WEXT is not set
grep -q "^# CONFIG_CFG80211_WEXT is not set" "$CONFIG_FILE" && \
    echo "✔ # CONFIG_CFG80211_WEXT is not set" || \
    echo "✘ # CONFIG_CFG80211_WEXT is not set (未禁用)"