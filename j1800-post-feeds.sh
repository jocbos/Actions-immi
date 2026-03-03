#!/bin/bash
# j1800-post-feeds.sh - feeds 更新后脚本（简化版）

echo "========================================="
echo "🚀 开始 J1800/升腾 C92 post-feeds 配置"
echo "========================================="

WORKSPACE=$GITHUB_WORKSPACE
cd "$WORKSPACE/openwrt" || exit 1

echo "✅ 已进入 openwrt 目录: $(pwd)"

# ===========================================
# 1. 安装 USB 网卡驱动
# ===========================================
echo "🔌 安装 USB 网卡驱动..."

USB_PACKAGES=(
    "kmod-usb-net-rtl8152"
    "r8152-firmware"
    "kmod-usb-net-cdc-ncm"
    "kmod-usb-net"
    "usbutils"
)

for pkg in "${USB_PACKAGES[@]}"; do
    echo "   - 安装 $pkg"
    ./scripts/feeds install "$pkg" > /dev/null 2>&1 && echo "     ✅ 成功" || echo "     ⚠️ 失败"
done

# ===========================================
# 2. 安装功能包 (iStoreOS 版)
# ===========================================
echo "📦 安装功能包..."

PACKAGES=(
    "mwan3"
    "luci-app-mwan3"
    "smartdns"
    "luci-app-smartdns"
    "zerotier"
    "luci-app-zerotier"
    "luci-app-upnp"
    "miniupnpd-iptables"
    "ksmbd-server"
    "luci-app-ksmbd"
    "luci-app-diskman"
    "luci-compat"
    "luci-i18n-mwan3-zh-cn"
    "luci-i18n-smartdns-zh-cn"
    "luci-i18n-zerotier-zh-cn"
    "luci-i18n-upnp-zh-cn"
    "luci-i18n-ksmbd-zh-cn"
)

for pkg in "${PACKAGES[@]}"; do
    echo "   - 安装 $pkg"
    ./scripts/feeds install "$pkg" > /dev/null 2>&1 && echo "     ✅ 成功" || echo "     ⚠️ 失败"
done

# ===========================================
# 3. 创建安装记录
# ===========================================
cat > "$WORKSPACE/feeds-installed.txt" <<EOF
# J1800 编译 feeds 安装记录
# 生成时间: $(date)

已安装的 USB 驱动:
$(for pkg in "${USB_PACKAGES[@]}"; do echo "- $pkg"; done)

已安装的功能包:
$(for pkg in "${PACKAGES[@]}"; do echo "- $pkg"; done)
EOF

echo "📝 安装记录已保存到: $WORKSPACE/feeds-installed.txt"

# ===========================================
# 4. 完成
# ===========================================
cd "$WORKSPACE" || true

echo "========================================="
echo "✅ j1800-post-feeds.sh 执行完成!"
echo "========================================="
exit 0
