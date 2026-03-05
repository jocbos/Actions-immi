#!/bin/bash
# j1800-post-feeds.sh - 精简优化版

echo "========================================="
echo "🚀 开始 J1800/升腾 C92 post-feeds 配置"
echo "========================================="

WORKSPACE=$GITHUB_WORKSPACE
cd "$WORKSPACE/openwrt" || exit 1

echo "✅ 已进入 openwrt 目录: $(pwd)"

# ===========================================
# 1. USB 网卡驱动（必须）
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
# 2. 核心功能包（你真正需要的）
# ===========================================
echo "📦 安装核心功能包..."

CORE_PACKAGES=(
    # 网络功能
    "mwan3"
    "luci-app-mwan3"
    "smartdns"
    "luci-app-smartdns"
    "zerotier"
    "luci-app-zerotier"
    
    
    # UPnP
    "luci-app-upnp"
    "miniupnpd-iptables"
    
    # 文件共享
    "ksmbd-server"
    "luci-app-ksmbd"
    "webdav2"
    "davfs2"
    
    # 下载工具
    "transmission-daemon"
    "transmission-web-control"
    "luci-app-transmission"
    "qbittorrent"
    "luci-app-qbittorrent"
    
    # 磁盘管理
    "luci-app-diskman"
    "luci-compat"
    
    # iStore
    "luci-app-istorex"
    
    # 运维工具
    "luci-app-ttyd"
    "ttyd"
    "luci-app-nlbwmon"
    "nlbwmon"
    "luci-app-watchcat"
    "luci-app-cpu-status"
    "cpufreq"
    
    # 内存优化
    "zram-swap"
    "luci-app-zram-swap"
    
    # 中文包
    "luci-i18n-mwan3-zh-cn"
    "luci-i18n-smartdns-zh-cn"
    "luci-i18n-zerotier-zh-cn"
    "luci-i18n-upnp-zh-cn"
    "luci-i18n-ksmbd-zh-cn"
    "luci-i18n-transmission-zh-cn"
)

for pkg in "${CORE_PACKAGES[@]}"; do
    echo "   - 安装 $pkg"
    ./scripts/feeds install "$pkg" > /dev/null 2>&1 && echo "     ✅ 成功" || echo "     ⚠️ 失败"
done

# ===========================================
# 3. 创建安装记录
# ===========================================
cat > "$WORKSPACE/feeds-installed.txt" <<EOF
# J1800 编译 feeds 安装记录
# 生成时间: $(date)

USB驱动: ${#USB_PACKAGES[@]} 个
核心功能包: ${#CORE_PACKAGES[@]} 个
EOF

echo "📝 安装记录已保存"

# ===========================================
# 4. 完成
# ===========================================
cd "$WORKSPACE" || true

echo "========================================="
echo "✅ j1800-post-feeds.sh 执行完成!"
echo "========================================="
echo "📊 总共处理: $((${#USB_PACKAGES[@]} + ${#CORE_PACKAGES[@]})) 个包"
echo "========================================="
exit 0
