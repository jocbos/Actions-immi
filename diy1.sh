#!/bin/bash
# 自定义预编译脚本 - HomeProxy版 (修复 transmission 依赖)

# 添加额外的软件源（先去重）
sed -i '/kenzo/d' feeds.conf.default
sed -i '/small/d' feeds.conf.default
echo "src-git kenzo https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default
echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default

# 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# ===== 修复 luci-app-transmission 的依赖 =====
# 将依赖从 transmission-web-control 改为 transmission-web
if [ -f feeds/kenzo/luci-app-transmission/Makefile ]; then
    sed -i 's/transmission-web-control/transmission-web/g' feeds/kenzo/luci-app-transmission/Makefile
    echo "已修改 kenzo 源中的 luci-app-transmission 依赖"
fi
if [ -f feeds/small/luci-app-transmission/Makefile ]; then
    sed -i 's/transmission-web-control/transmission-web/g' feeds/small/luci-app-transmission/Makefile
    echo "已修改 small 源中的 luci-app-transmission 依赖"
fi

# 重新安装 feeds 以确保修改生效
./scripts/feeds install -a

# 修改默认IP为 192.168.2.1
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 修改默认主题为 argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 添加默认防火墙规则（可选）
cat >> package/network/config/firewall/files/firewall.user <<EOF
# 自定义防火墙规则
echo 1 > /proc/sys/net/ipv4/ip_forward
EOF

# 优化系统参数
mkdir -p files/etc/sysctl.d
cat >> files/etc/sysctl.d/99-custom.conf <<EOF
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF

# 添加开机自启脚本（可选）
mkdir -p files/etc/init.d
cat >> files/etc/init.d/custom-startup <<EOF
#!/bin/sh /etc/rc.common
START=99
start() {
    block mount
}
EOF
chmod +x files/etc/init.d/custom-startup

# ===== 强制取消 wget =====
sed -i '/CONFIG_PACKAGE_wget/d' .config
echo "# CONFIG_PACKAGE_wget is not set" >> .config
echo "# CONFIG_PACKAGE_wget-ssl is not set" >> .config
echo "# CONFIG_PACKAGE_wget-nossl is not set" >> .config

# ===== 确保 transmission 配置正确 =====
sed -i '/CONFIG_PACKAGE_transmission-web-control/d' .config
echo "# CONFIG_PACKAGE_transmission-web-control is not set" >> .config
sed -i '/CONFIG_PACKAGE_transmission-web/d' .config
echo "CONFIG_PACKAGE_transmission-web=y" >> .config

make defconfig

echo "DIY script completed successfully!"
