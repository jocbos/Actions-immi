#!/bin/bash
# new.sh - XG-040G-MD 小楼版预配置脚本
# 适用于 immortalwrt 25.12 分支
# 执行时机: feeds 更新前

set -e  # 出错立即退出

echo "========================================="
echo "开始执行 new.sh 预配置脚本"
echo "========================================="

# 进入 openwrt 目录
cd openwrt || exit 1

# ===== 1. 添加第三方软件源 =====
echo "添加第三方软件源..."

cat >> feeds.conf.default <<EOF

# PassWall 官方源
src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main

# kenzok8 插件源（包含常用插件）
src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master
src-git small https://github.com/kenzok8/small.git;master

#  immortalwrt 官方源（确保完整）
src-git immortalwrt_luci https://github.com/immortalwrt/luci.git;openwrt-21.02
src-git immortalwrt_packages https://github.com/immortalwrt/packages.git;openwrt-21.02
EOF

echo "✅ 软件源添加完成"

# ===== 2. 创建自定义文件目录 =====
echo "创建自定义文件目录..."
mkdir -p files/etc/uci-defaults
mkdir -p files/etc/init.d
mkdir -p files/etc/sysctl.d
mkdir -p files/etc/modules.d
echo "✅ 目录创建完成"

# ===== 3. 设置默认IP地址 =====
echo "设置默认IP为 192.168.100.254..."
cat > files/etc/uci-defaults/99-ip-set << 'EOF'
#!/bin/sh
# 设置默认IP
uci set network.lan.ipaddr='192.168.100.254'
uci set network.lan.netmask='255.255.255.0'
uci commit network

# 设置主机名
uci set system.@system[0].hostname='XG-040G-MD'
uci commit system

exit 0
EOF
chmod +x files/etc/uci-defaults/99-ip-set
echo "✅ 默认IP设置完成"

# ===== 4. 创建 NPU 驱动加载配置 =====
echo "配置 NPU 驱动加载..."
cat > files/etc/modules.d/10-airoha-npu << 'EOF'
# Airoha EN7581 NPU 驱动
mtk_hnat
mtk_npu
EOF
echo "✅ NPU 配置完成"

# ===== 5. 创建系统优化配置 =====
echo "创建系统优化配置..."
cat > files/etc/sysctl.d/99-optimize.conf << 'EOF'
# 网络优化
net.core.rmem_max = 262144
net.core.wmem_max = 262144
net.ipv4.tcp_rmem = 16384 43689 262144
net.ipv4.tcp_wmem = 16384 43689 262144
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
EOF
echo "✅ 系统优化配置完成"

# ===== 6. 创建 vsftpd 默认配置 =====
echo "创建 vsftpd 默认配置..."
mkdir -p files/etc
cat > files/etc/vsftpd.conf << 'EOF'
# 基本设置
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
chroot_local_user=YES
allow_writeable_chroot=YES
listen=YES
listen_ipv6=NO
pam_service_name=vsftpd
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=31000
EOF
echo "✅ vsftpd 配置完成"

echo "========================================="
echo "new.sh 预配置脚本执行完成！"
echo "========================================="
