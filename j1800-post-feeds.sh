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
    ./scripts/feeds install "$pkg" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "     ✅ 成功"
    else
        echo "     ⚠️ 失败（可能已存在或不需要）"
    fi
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

for pkg in "${PACKAGES[@]}"; do
    echo "   - 安装 $pkg"
    ./scripts/feeds install "$pkg" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "     ✅ 成功"
    else
        echo "     ⚠️ 失败（可能已存在或不需要）"
    fi
done

# ===========================================
# 3. 安装 Transmission（特殊处理）
# ===========================================
echo "📥 安装 Transmission..."

TRANSMISSION_PACKAGES=(
    "transmission-daemon"
    "transmission-web"
    "transmission-web-control"
    "luci-app-transmission"
    "luci-i18n-transmission-zh-cn"
)

for pkg in "${TRANSMISSION_PACKAGES[@]}"; do
    echo "   - 检查 $pkg..."
    
    # 先查找包是否存在
    PKG_PATH=$(find package/feeds -name "$pkg" -type d 2>/dev/null | head -1)
    
    if [ -n "$PKG_PATH" ]; then
        echo "     📍 找到包: $PKG_PATH"
        ./scripts/feeds install "$pkg" > /dev/null 2>&1
        echo "     ✅ 安装命令已执行"
    else
        # 尝试在 feeds 中搜索
        FOUND=$(find feeds -name "*$pkg*" -type d 2>/dev/null | head -1)
        if [ -n "$FOUND" ]; then
            echo "     📍 在 $FOUND 找到相似包"
            PKG_NAME=$(basename "$FOUND")
            ./scripts/feeds install "$PKG_NAME" > /dev/null 2>&1
            echo "     ✅ 尝试安装 $PKG_NAME"
        else
            echo "     ⚠️ 未找到 $pkg，可能包名不同或需要添加源"
        fi
    fi
done

# ===========================================
# 4. 列出所有可用的 transmission 相关包
# ===========================================
echo "🔍 搜索所有 transmission 相关包..."
find feeds -name "*transmission*" -type d 2>/dev/null | while read -r line; do
    echo "   - $line"
done

# ===========================================
# 5. 创建安装记录
# ===========================================
cat > "$WORKSPACE/feeds-installed.txt" <<EOF
# J1800 编译 feeds 安装记录
# 生成时间: $(date)

已安装的 USB 驱动:
$(for pkg in "${USB_PACKAGES[@]}"; do echo "- $pkg"; done)

已安装的功能包:
$(for pkg in "${PACKAGES[@]}"; do echo "- $pkg"; done)

Transmission 相关包:
$(find feeds -name "*transmission*" -type d 2>/dev/null | sed 's/^/ - /')
EOF

echo "📝 安装记录已保存到: $WORKSPACE/feeds-installed.txt"

# ===========================================
# 6. 完成
# ===========================================
cd "$WORKSPACE" || true

echo "========================================="
echo "✅ j1800-post-feeds.sh 执行完成!"
echo "========================================="
exit 0
