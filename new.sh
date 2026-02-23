#!/bin/bash
# new.sh - XG-040G-MD 小楼版预配置脚本
# 适用于 immortalwrt 25.12 分支
# 执行时机: feeds 更新前

set -e  # 出错立即退出

echo "========================================="
echo "开始执行 new.sh 预配置脚本"
echo "========================================="
echo "当前目录: $(pwd)"
echo "列出当前目录内容:"
ls -la

# ===== 1. 检查 openwrt 目录是否存在 =====
if [ ! -d "openwrt" ]; then
    echo "❌ 错误: openwrt 目录不存在！"
    echo "当前目录内容:"
    ls -la
    exit 1
fi

echo "✅ 找到 openwrt 目录"
echo "openwrt 目录内容:"
ls -la openwrt/

# ===== 2. 添加第三方软件源 =====
echo "添加第三方软件源..."

cat >> openwrt/feeds.conf.default <<EOF

# PassWall 官方源
src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main

# kenzok8 插件源（包含常用插件）
src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master
src-git small https://github.com/kenzok8/small.git;master

# immortalwrt 官方源（确保完整）
src-git immortalwrt_luci https://github.com/immortalwrt/luci.git;openwrt-21.02
src-git immortalwrt_packages https://github.com/immortalwrt/packages.git;openwrt-21.02
EOF

echo "✅ 软件源添加完成"
echo "feeds.conf.default 内容:"
cat openwrt/feeds.conf.default

# ===== 3. 创建自定义文件目录 =====
echo "创建自定义文件目录..."
mkdir -p openwrt/files/etc/uci-defaults
mkdir -p openwrt/files/etc/init.d
mkdir -p openwrt/files/etc/sysctl.d
mkdir -p openwrt/files/etc/modules.d
mkdir -p openwrt/files/etc/hotplug.d/block
mkdir -p openwrt/files/etc/ppp
mkdir -p openwrt/files/root
echo "✅ 目录创建完成"

# ===== 4. 设置默认IP地址 =====
echo "设置默认IP为 192.168.100.254..."
cat > openwrt/files/etc/uci-defaults/99-ip-set << 'EOF'
#!/bin/sh
# 设置默认IP
uci set network.lan.ipaddr='192.168.100.254'
uci set network.lan.netmask='255.255.255.0'
uci commit network

# 设置主机名
uci set system.@system[0].hostname='XG-040G-MD'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system

# 设置中文
uci set luci.main.lang='zh_cn'
uci commit luci

exit 0
EOF
chmod +x openwrt/files/etc/uci-defaults/99-ip-set
echo "✅ 默认IP设置完成"

# ===== 5. 创建 NPU 驱动加载配置 =====
echo "配置 NPU 驱动加载..."
cat > openwrt/files/etc/modules.d/10-airoha-npu << 'EOF'
# Airoha EN7581 NPU 驱动
mtk_hnat
mtk_npu
EOF
echo "✅ NPU 配置完成"

# ===== 6. 创建系统优化配置 =====
echo "创建系统优化配置..."
cat > openwrt/files/etc/sysctl.d/99-optimize.conf << 'EOF'
# 网络优化
net.core.rmem_max = 262144
net.core.wmem_max = 262144
net.ipv4.tcp_rmem = 16384 43689 262144
net.ipv4.tcp_wmem = 16384 43689 262144
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1

# 内存优化
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
echo "✅ 系统优化配置完成"

# ===== 7. 创建 vsftpd 默认配置 =====
echo "创建 vsftpd 默认配置..."
cat > openwrt/files/etc/vsftpd.conf << 'EOF'
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

# 被动模式
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=31000
EOF
echo "✅ vsftpd 配置完成"

# ===== 8. 创建 USB 自动挂载脚本 =====
echo "创建 USB 自动挂载脚本..."
cat > openwrt/files/etc/hotplug.d/block/10-automount << 'EOF'
#!/bin/sh
case "$ACTION" in
    add)
        for i in /sys/block/*/device; do
            device="$(basename "$(dirname "$(dirname "$i")")")"
            if [ ! -d "/mnt/$device" ] && [ -b "/dev/$device" ]; then
                mkdir -p "/mnt/$device"
                mount "/dev/$device" "/mnt/$device" 2>/dev/null && \
                    logger "USB 设备已自动挂载到 /mnt/$device"
            fi
        done
        ;;
esac
EOF
chmod +x openwrt/files/etc/hotplug.d/block/10-automount
echo "✅ USB 自动挂载脚本完成"

# ===== 9. 创建 PPPoE 自动重连脚本 =====
echo "创建 PPPoE 自动重连脚本..."
cat > openwrt/files/etc/ppp/ip-up << 'EOF'
#!/bin/sh
# PPPoE 连接成功时执行
logger "PPPoE 连接成功，IP: $4"
EOF
chmod +x openwrt/files/etc/ppp/ip-up

cat > openwrt/files/etc/ppp/ip-down << 'EOF'
#!/bin/sh
# PPPoE 断开时执行
logger "PPPoE 连接断开"
EOF
chmod +x openwrt/files/etc/ppp/ip-down
echo "✅ PPPoE 脚本完成"

# ===== 10. 创建欢迎信息 =====
echo "创建欢迎信息..."
cat > openwrt/files/etc/banner << 'EOF'
  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__|                   XG-040G-MD 小楼版

 -----------------------------------------------------
 版本: ImmortalWrt 25.12
 设备: XG-040G-MD (Airoha EN7581)
 功能: PassWall + HomeProxy + mwan3 + vsftpd + ksmbd
 默认IP: 192.168.100.254
 -----------------------------------------------------
EOF
echo "✅ 欢迎信息完成"

echo "========================================="
echo "new.sh 预配置脚本执行完成！"
echo "========================================="
echo "创建的文件列表："
find openwrt/files -type f | sort
