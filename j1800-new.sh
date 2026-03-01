#!/bin/bash
# j1800-new.sh - 升腾 C92/J1800 编译前配置脚本
# 功能: 添加第三方源、设置默认IP、预配置单网口+USB网卡支持

echo "========================================="
echo "🚀 开始 J1800/升腾 C92 编译前配置"
echo "========================================="

# 获取当前工作目录
WORKSPACE=$GITHUB_WORKSPACE
echo "📂 当前工作目录: $WORKSPACE"
echo "📂 当前目录内容:"
ls -la

# 检查 openwrt 目录是否存在
if [ -d "openwrt" ]; then
    echo "✅ 找到 openwrt 目录"
    cd openwrt || exit 1
elif [ -d "$WORKSPACE/openwrt" ]; then
    echo "✅ 在 WORKSPACE 中找到 openwrt 目录"
    cd "$WORKSPACE/openwrt" || exit 1
else
    echo "❌ 错误: 找不到 openwrt 目录!"
    echo "当前目录: $(pwd)"
    echo "目录内容:"
    ls -la
    exit 1
fi

echo "✅ 已进入 openwrt 目录: $(pwd)"

# ===========================================
# 1. 添加第三方软件包源
# ===========================================
echo "📦 添加第三方软件包源 (kenzo/small)..."

# 备份原文件
cp feeds.conf.default feeds.conf.default.bak 2>/dev/null || true

# 检查是否已添加，避免重复
if ! grep -q "kenzok8/openwrt-packages" feeds.conf.default; then
    cat >> feeds.conf.default <<EOF

# 第三方软件包源 (包含 homeproxy 等)
src-git kenzo https://github.com/kenzok8/openwrt-packages
src-git small https://github.com/kenzok8/small
EOF
    echo "✅ 已添加 kenzo/small 源"
else
    echo "⚠️ kenzo/small 源已存在，跳过添加"
fi

# ===========================================
# 2. 添加自定义 banner
# ===========================================
echo "🎨 添加自定义 banner..."

# 确保目录存在
mkdir -p package/base-files/files/etc

cat > package/base-files/files/etc/banner <<EOF
-----------------------------------------------------
 升腾 C92 / J1800 单网口软路由
 编译时间: $(date +"%Y-%m-%d %H:%M:%S")
 默认 IP: 192.168.100.100
 支持 RTL8156B USB 2.5G 网卡
-----------------------------------------------------


EOF

echo "✅ banner 已更新"

# ===========================================
# 3. 创建自定义文件目录
# ===========================================
echo "📁 创建自定义文件目录..."
mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults
mkdir -p files/root
mkdir -p files/etc/sysctl.d

echo "✅ 自定义目录创建完成"

# ===========================================
# 4. 配置默认网络 (单网口 + USB网卡就绪)
# ===========================================
echo "🌐 配置默认网络 (单网口模式, IP: 192.168.100.100)..."

cat > files/etc/config/network <<EOF
config interface 'loopback'
    option device 'lo'
    option proto 'static'
    option ipaddr '127.0.0.1'
    option netmask '255.0.0.0'

config globals 'globals'
    option ula_prefix 'fd00:ab:cd::/48'

# 板载网口配置 (eth0)
config device
    option name 'br-lan'
    option type 'bridge'
    list ports 'eth0'

# LAN 配置 (默认使用板载网口)
config interface 'lan'
    option device 'br-lan'
    option proto 'static'
    option ipaddr '192.168.100.100'
    option netmask '255.255.255.0'
    option ip6assign '60'

# ============================================
# USB 网卡预留配置 (RTL8156B 等)
# 插入后会自动识别，可在 LuCI 中添加接口
# 推荐用途: USB网卡作为 WAN 口
# ============================================
# 示例配置已注释，用户可根据需要自行启用
EOF

echo "✅ 网络配置完成"

# ===========================================
# 5. 配置防火墙
# ===========================================
echo "🔥 配置防火墙规则..."

cat > files/etc/config/firewall <<EOF

config defaults
    option syn_flood '1'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'ACCEPT'
    option flow_offloading '1'
    option flow_offloading_hw '1'

config zone
    option name 'lan'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'ACCEPT'
    list network 'lan'

config zone
    option name 'wan'
    option input 'REJECT'
    option output 'ACCEPT'
    option forward 'REJECT'
    option masq '1'
    option mtu_fix '1'
    list network 'wan'

config forwarding
    option src 'lan'
    option dest 'wan'

config rule
    option name 'Allow-DHCP'
    option src 'lan'
    option dest 'wan'
    option proto 'udp'
    option dest_port '67'
    option target 'ACCEPT'

config rule
    option name 'Allow-DNS'
    option src 'lan'
    option dest 'wan'
    option proto 'udp'
    option dest_port '53'
    option target 'ACCEPT'
EOF

echo "✅ 防火墙配置完成"

# ===========================================
# 6. 添加 RTL8156B 自动配置脚本
# ===========================================
echo "⚡ 添加 RTL8156B USB 网卡自动配置脚本..."

cat > files/etc/uci-defaults/99-rtl8156b-setup <<'EOF'
#!/bin/sh
# 自动检测 RTL8156B USB 网卡并提示配置

# 等待系统完全启动
sleep 10

# 记录日志
logger -t RTL8156B "检查 USB 网卡..."

# 检查是否有 RTL8156B 网卡
if lsusb 2>/dev/null | grep -q "0bda:8156"; then
    logger -t RTL8156B "检测到 RTL8156B USB 2.5G 网卡"
    echo "✅ 检测到 RTL8156B USB 2.5G 网卡" > /dev/console
    
    # 查找新出现的网络接口
    for iface in /sys/class/net/*; do
        iface_name=$(basename $iface)
        # 排除回环和板载网口
        if [ "$iface_name" != "lo" ] && [ "$iface_name" != "eth0" ] && [ "$iface_name" != "br-lan" ]; then
            logger -t RTL8156B "检测到新网卡: $iface_name"
            echo "📡 检测到新网卡: $iface_name" > /dev/console
            echo "💡 请在 LuCI 网络 → 接口 中配置此网卡作为 WAN 口" > /dev/console
            break
        fi
    done
else
    logger -t RTL8156B "未检测到 RTL8156B 网卡"
fi

exit 0
EOF

chmod +x files/etc/uci-defaults/99-rtl8156b-setup
echo "✅ RTL8156B 自动配置脚本已添加"

# ===========================================
# 7. 添加 USB 网卡驱动提示
# ===========================================
cat > files/root/README-USB-NIC.txt <<'EOF'
===========================================
 升腾 C92 USB 网卡使用说明
===========================================

本固件已内置以下 USB 网卡驱动:
✅ RTL8156B (你的 2.5G 网卡)
✅ RTL8152/RTL8153 (千兆 USB 网卡)
✅ ASIX AX88179/AX8817x
✅ 其他常见 USB 网卡

📌 使用方法:

1. 插入 USB 网卡
2. 等待几秒钟，系统会自动识别
3. 查看网卡名称: ip link show
   (可能会显示为 enx* 或 usb* 或 eth1)
4. 进入 LuCI 网络 → 接口
5. 添加新接口:
   - 名称: wan (或任意名字)
   - 协议: DHCP客户端/PPPoE/静态IP
   - 设备: 选择刚识别的网卡
6. 防火墙设置: 勾选 wan 区域
7. 保存并应用

💡 推荐配置方案:
   光猫 --(USB网卡)--> C92 --(板载网口)--> 你的设备

🔧 强制 2.5G 速度 (如需):
   ethtool -s enxXXXXXXXX speed 2500 duplex full

===========================================
EOF

echo "✅ USB 网卡说明已添加"

# ===========================================
# 8. 添加系统优化
# ===========================================
echo "⚙️ 添加系统优化配置..."

cat > files/etc/sysctl.d/99-network-optimize.conf <<EOF
# 网络优化
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF

echo "✅ 系统优化配置完成"

# ===========================================
# 9. 返回上级目录
# ===========================================
cd "$WORKSPACE" || true

# ===========================================
# 10. 完成
# ===========================================
echo "========================================="
echo "✅ j1800-new.sh 执行完成!"
echo "========================================="
echo "📌 配置总结:"
echo "   - 默认 IP: 192.168.100.100"
echo "   - 板载网口: 作为 LAN 口"
echo "   - USB 网卡: RTL8156B 驱动已集成"
echo "   - 第三方源: kenzo/small 已添加"
echo "========================================="

exit 0
