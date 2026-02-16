#!/bin/bash
# 网关精简版 DIY 脚本

# 添加软件源（如果需要，可以不加）
# sed -i '/kenzo/d' feeds.conf.default
# sed -i '/small/d' feeds.conf.default
# echo "src-git kenzo https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default
# echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default

# 修改默认IP为 192.168.2.1
sed -i 's/192.168.1.1/192.168.100.254/g' package/base-files/files/bin/config_generate

# 修改默认主题为 argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 系统优化参数
mkdir -p files/etc/sysctl.d
cat >> files/etc/sysctl.d/99-custom.conf <<EOF
# 网络优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

# 默认防火墙规则
cat >> package/network/config/firewall/files/firewall.user <<EOF
# 开启转发
echo 1 > /proc/sys/net/ipv4/ip_forward
EOF

# 强制取消 wget
sed -i '/CONFIG_PACKAGE_wget/d' .config
echo "# CONFIG_PACKAGE_wget is not set" >> .config
echo "# CONFIG_PACKAGE_wget-ssl is not set" >> .config
echo "# CONFIG_PACKAGE_wget-nossl is not set" >> .config

make defconfig

echo "✅ 网关精简版 DIY 脚本执行完成"
