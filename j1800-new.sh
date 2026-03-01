#!/bin/bash
# j1800-new.sh - 升腾 C92/J1800 编译前配置脚本

echo "========================================="
echo "🚀 开始 J1800/升腾 C92 编译前配置"
echo "========================================="

WORKSPACE=$GITHUB_WORKSPACE
cd "$WORKSPACE/openwrt" || exit 1

echo "✅ 已进入 openwrt 目录: $(pwd)"

# ===========================================
# 1. 添加第三方软件包源
# ===========================================
echo "📦 添加第三方软件包源..."

# 备份原文件
cp feeds.conf.default feeds.conf.default.bak 2>/dev/null || true

# 检查并添加源
if ! grep -q "kenzok8/openwrt-packages" feeds.conf.default; then
    cat >> feeds.conf.default <<EOF

# 第三方软件包源
src-git kenzo https://github.com/kenzok8/openwrt-packages
src-git small https://github.com/kenzok8/small
src-git helloworld https://github.com/fw876/helloworld
EOF
    echo "✅ 已添加第三方源"
else
    echo "⚠️ 第三方源已存在，跳过添加"
fi

# ===========================================
# 2. 添加自定义 banner
# ===========================================
echo "🎨 添加自定义 banner..."

mkdir -p package/base-files/files/etc

cat > package/base-files/files/etc/banner <<EOF
-----------------------------------------------------
 升腾 C92 / J1800 单网口软路由
 编译时间: $(date +"%Y-%m-%d %H:%M:%S")
 默认 IP: 192.168.100.100
 支持 RTL8156B USB 2.5G 网卡
-----------------------------------------------------


EOF

# ===========================================
# 3. 创建自定义文件目录
# ===========================================
echo "📁 创建自定义文件目录..."
mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults
mkdir -p files/root
mkdir -p files/etc/sysctl.d

# ===========================================
# 4. 配置默认网络
# ===========================================
echo "🌐 配置默认网络 (IP: 192.168.100.100)..."

cat > files/etc/config/network <<EOF
config interface 'loopback'
    option device 'lo'
    option proto 'static'
    option ipaddr '127.0.0.1'
    option netmask '255.0.0.0'

config globals 'globals'
    option ula_prefix 'fd00:ab:cd::/48'

config device
    option name 'br-lan'
    option type 'bridge'
    list ports 'eth0'

config interface 'lan'
    option device 'br-lan'
    option proto 'static'
    option ipaddr '192.168.100.100'
    option netmask '255.255.255.0'
    option ip6assign '60'
EOF

# ===========================================
# 5. 配置防火墙
# ===========================================
echo "🔥 配置防火墙..."

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

config forwarding
    option src 'lan'
    option dest 'wan'
EOF

# ===========================================
# 6. 添加 RTL8156B 自动配置脚本
# ===========================================
echo "⚡ 添加 RTL8156B USB 网卡自动配置脚本..."

cat > files/etc/uci-defaults/99-rtl8156b-setup <<'EOF'
#!/bin/sh
sleep 10
if lsusb 2>/dev/null | grep -q "0bda:8156"; then
    logger -t RTL8156B "检测到 RTL8156B USB 2.5G 网卡"
    echo "✅ 检测到 RTL8156B USB 2.5G 网卡" > /dev/console
fi
exit 0
EOF

chmod +x files/etc/uci-defaults/99-rtl8156b-setup

# ===========================================
# 7. 添加系统优化
# ===========================================
echo "⚙️ 添加系统优化..."

cat > files/etc/sysctl.d/99-network-optimize.conf <<EOF
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF

# ===========================================
# 8. 完成
# ===========================================
cd "$WORKSPACE" || true

echo "========================================="
echo "✅ j1800-new.sh 执行完成!"
echo "========================================="
exit 0
