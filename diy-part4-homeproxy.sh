#!/bin/bash
# 自定义预编译脚本 - HomeProxy版 (修复wget禁用)

# 进入 openwrt 目录
cd openwrt || exit 1

# 添加额外的软件源（如果需要）
# 例如添加一些额外的包
cat >> feeds.conf.default <<EOF
src-git small8 https://github.com/kenzok8/small-package
EOF

# 更新 feeds（可选，如果需要在脚本中提前更新）
./scripts/feeds update -a
./scripts/feeds install -a

# 修改默认IP为 192.168.2.1 (避免与光猫冲突)
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# 修改默认主题为 argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 添加默认防火墙规则（可选）
cat >> package/network/config/firewall/files/firewall.user <<EOF
# 自定义防火墙规则
# 例如开启IP转发
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
    # 启动其他服务
}
EOF
chmod +x files/etc/init.d/custom-startup

# ===== 强制取消 wget（避免编译失败）=====
# 确保在 openwrt 目录下执行
sed -i '/CONFIG_PACKAGE_wget/d' .config
echo "# CONFIG_PACKAGE_wget is not set" >> .config
echo "# CONFIG_PACKAGE_wget-ssl is not set" >> .config
echo "# CONFIG_PACKAGE_wget-nossl is not set" >> .config
make defconfig

# 返回原目录（可选，不影响后续步骤）
cd $GITHUB_WORKSPACE

echo "DIY script completed!"
