#!/bin/bash
# j1800-post-feeds.sh - feeds 更新后脚本

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
    ./scripts/feeds install "$pkg" 2>/dev/null || true
done

# ===========================================
# 2. 安装功能包
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
    "miniupnpd-nftables"
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

# Transmission 包名可能不同，尝试几种可能
echo "   - 安装 Transmission..."
./scripts/feeds install transmission-daemon 2>/dev/null || \
./scripts/feeds install transmission-daemon-openssl 2>/dev/null || \
echo "     ⚠️ Transmission 未找到，可后续手动安装"

./scripts/feeds install luci-app-transmission 2>/dev/null || true
./scripts/feeds install luci-i18n-transmission-zh-cn 2>/dev/null || true

# 安装其他包
for pkg in "${PACKAGES[@]}"; do
    echo "   - 安装 $pkg"
    ./scripts/feeds install "$pkg" 2>/dev/null || echo "     ⚠️ 安装失败"
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
- transmission (尝试安装)
EOF

echo "📝 安装记录已保存"

# ===========================================
# 4. 完成
# ===========================================
cd "$WORKSPACE" || true

echo "========================================="
echo "✅ j1800-post-feeds.sh 执行完成!"
echo "========================================="
exit 0
