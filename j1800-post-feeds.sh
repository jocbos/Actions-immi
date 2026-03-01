#!/bin/bash
# j1800-post-feeds.sh - feeds 更新后脚本
# 功能: 检查 feeds、应用补丁、处理依赖

echo "========================================="
echo "🚀 开始 J1800/升腾 C92 post-feeds 配置"
echo "========================================="

cd openwrt || exit 1

# ===========================================
# 1. 检查 feeds 是否成功添加
# ===========================================
echo "📦 检查 feeds 状态..."

# 检查 kenzo feed
if [ -d "feeds/kenzo" ]; then
    echo "✅ kenzo feed 已添加"
    echo "   - 包含: homeproxy 等包"
else
    echo "⚠️ kenzo feed 未找到，尝试重新链接..."
    ./scripts/feeds update kenzo
    ./scripts/feeds install -a -p kenzo
fi

# 检查 small feed
if [ -d "feeds/small" ]; then
    echo "✅ small feed 已添加"
else
    echo "⚠️ small feed 未找到，尝试重新链接..."
    ./scripts/feeds update small
    ./scripts/feeds install -a -p small
fi

# ===========================================
# 2. 确保 USB 网卡相关的包正确安装
# ===========================================
echo "🔌 确保 USB 网卡相关包已安装..."

# 从 feeds 安装 USB 相关包
./scripts/feeds install kmod-usb-net-rtl8152
./scripts/feeds install r8152-firmware
./scripts/feeds install kmod-usb-net-cdc-ncm
./scripts/feeds install kmod-usb-net
./scripts/feeds install usbutils

# ===========================================
# 3. 检查 homeproxy 依赖
# ===========================================
echo "🛡️ 检查 homeproxy 相关包..."

if [ -d "feeds/kenzo/luci-app-homeproxy" ]; then
    echo "✅ homeproxy 已找到"
    # 安装 homeproxy 及其依赖
    ./scripts/feeds install -f -p kenzo luci-app-homeproxy
    ./scripts/feeds install sing-box
    ./scripts/feeds install v2ray-geodata
else
    echo "⚠️ 警告: homeproxy 未找到，请检查 kenzo feed"
fi

# ===========================================
# 4. 处理可能的包冲突
# ===========================================
echo "🔄 检查并处理包冲突..."

# 删除可能冲突的包
find ./ -name '*dnsmasq*' -type d -name '*copy*' -exec rm -rf {} + 2>/dev/null || true
find ./ -name '*firewall*' -type d -name '*copy*' -exec rm -rf {} + 2>/dev/null || true

# ===========================================
# 5. 确保所有需要的包都已安装
# ===========================================
echo "📋 安装你指定的功能包..."

# 你指定的功能包列表
PACKAGES=(
    "mwan3"
    "luci-app-mwan3"
    "smartdns"
    "luci-app-smartdns"
    "zerotier"
    "luci-app-zerotier"
    "luci-app-homeproxy"
    "luci-app-upnp"
    "miniupnpd-nftables"
    "ksmbd-server"
    "luci-app-ksmbd"
    "transmission-daemon-openssl"
    "luci-app-transmission"
    "luci-app-diskman"
    "luci-compat"
)

# 尝试安装每个包
for pkg in "${PACKAGES[@]}"; do
    echo "   - 安装 $pkg"
    ./scripts/feeds install "$pkg"
done

# ===========================================
# 6. 创建 feeds 安装记录
# ===========================================
cat > feeds-installed.txt <<EOF
# J1800 编译 feeds 安装记录
# 生成时间: $(date)

已添加的 feeds:
- kenzo (包含 homeproxy)
- small

已安装的 USB 网卡驱动:
- kmod-usb-net-rtl8152 (RTL8156B)
- r8152-firmware
- kmod-usb-net-cdc-ncm
- kmod-usb-net

已安装的功能包:
$(for pkg in "${PACKAGES[@]}"; do echo "- $pkg"; done)
EOF

echo "📝 安装记录已保存到: feeds-installed.txt"

# ===========================================
# 7. 完成
# ===========================================
echo "========================================="
echo "✅ j1800-post-feeds.sh 执行完成!"
echo "========================================="
echo "📊 统计信息:"
echo "   - feeds 目录大小: $(du -sh feeds 2>/dev/null | cut -f1)"
echo "   - 已安装包数量: $(find feeds -name Makefile 2>/dev/null | wc -l)"
echo "========================================="

exit 0
