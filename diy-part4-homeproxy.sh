#!/bin/bash
# 自定义预编译脚本 - HomeProxy版 (已在openwrt目录内执行)

# 添加额外的软件源（先去重）
echo "=== 配置软件源 ==="
# 删除可能存在的旧源
sed -i '/kenzo/d' feeds.conf.default
sed -i '/small/d' feeds.conf.default
sed -i '/small8/d' feeds.conf.default

# 添加新源
echo "src-git kenzo https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default
echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default

# 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a
# ===== 新增：强制移除 transmission-web-control =====
echo ">>> 强制移除 transmission-web-control 的 Makefile"
rm -f package/feeds/*/transmission-web-control/Makefile
rm -f feeds/*/transmission-web-control/Makefile

# 重新安装 feeds 以确保其他包依赖正确（但 web-control 已经被删了）


# 修改默认IP为 192.168.2.1 (避免与光猫冲突)
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
# 网络优化
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
    # 挂载USB设备
    block mount
}
EOF
chmod +x files/etc/init.d/custom-startup

# ===== 强制取消 wget（避免编译失败）=====
sed -i '/CONFIG_PACKAGE_wget/d' .config
echo "# CONFIG_PACKAGE_wget is not set" >> .config
echo "# CONFIG_PACKAGE_wget-ssl is not set" >> .config
echo "# CONFIG_PACKAGE_wget-nossl is not set" >> .config
# 强制删除并禁用 transmission-web-control
sed -i '/CONFIG_PACKAGE_transmission-web-control/d' .config
echo "# CONFIG_PACKAGE_transmission-web-control is not set" >> .config

# 确保官方 web 被选中
sed -i '/CONFIG_PACKAGE_transmission-web/d' .config
echo "CONFIG_PACKAGE_transmission-web=y" >> .config
make defconfig

echo "DIY script completed successfully!"
