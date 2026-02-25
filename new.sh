#!/bin/bash
# new.sh - XG-040G-MD 小楼版预配置脚本
# 不带 PassWall，只保留基础功能

set -e

echo "========================================="
echo "开始执行 new.sh 预配置脚本"
echo "========================================="
echo "当前目录: $(pwd)"

# ===== 1. 备份原 feeds.conf.default =====
if [ -f "feeds.conf.default" ]; then
    cp feeds.conf.default feeds.conf.default.bak-$(date +%Y%m%d%H%M%S)
    echo "✅ 已备份原 feeds.conf.default"
fi

# ===== 2. 创建全新的 feeds.conf.default =====
echo "创建新的 feeds.conf.default..."
cat > feeds.conf.default << 'EOF'
# ImmortalWrt 官方源
src-git packages https://github.com/immortalwrt/packages.git
src-git luci https://github.com/immortalwrt/luci.git
src-git routing https://github.com/immortalwrt/routing.git
# src-git telephony https://github.com/immortalwrt/telephony.git
EOF
echo "✅ feeds.conf.default 创建完成"
echo "----------------------------------------"
cat feeds.conf.default
echo "----------------------------------------"

# ===== 3. 创建自定义文件目录 =====
echo ""
echo "创建自定义文件目录..."
mkdir -p files/etc/uci-defaults
mkdir -p files/etc/init.d
mkdir -p files/etc/sysctl.d
mkdir -p files/etc/modules.d
mkdir -p files/etc/hotplug.d/block
mkdir -p files/root
echo "✅ 目录创建完成"

# ===== 4. 设置默认IP地址 =====
echo ""
echo "设置默认IP为 192.168.100.254..."
cat > files/etc/uci-defaults/99-ip-set << 'EOF'
#!/bin/sh
uci set network.lan.ipaddr='192.168.100.254'
uci set network.lan.netmask='255.255.255.0'
uci commit network
uci set system.@system[0].hostname='XG-040G-MD'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
uci set luci.main.lang='zh_cn'
uci commit luci
exit 0
EOF
chmod +x files/etc/uci-defaults/99-ip-set
echo "✅ 默认IP设置完成"

# ===== 5. 创建 NPU 驱动加载配置 =====
echo ""
echo "配置 NPU 驱动加载..."
cat > files/etc/modules.d/10-airoha-npu << 'EOF'
# Airoha EN7581 NPU 驱动
mtk_hnat
mtk_npu
EOF
echo "✅ NPU 配置完成"

# ===== 6. 创建系统优化配置 =====
echo ""
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

# 内存优化
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
echo "✅ 系统优化配置完成"

# ===== 7. 创建 USB 自动挂载脚本 =====
echo ""
echo "创建 USB 自动挂载脚本..."
cat > files/etc/hotplug.d/block/10-automount << 'EOF'
#!/bin/sh
# USB 自动挂载脚本

case "$ACTION" in
    add)
        sleep 2
        for device in /sys/block/sd*; do
            [ -d "$device" ] || continue
            devname=$(basename "$device")
            if mount | grep -q "/dev/$devname"; then
                continue
            fi
            mkdir -p "/mnt/$devname"
            if mount "/dev/$devname" "/mnt/$devname" 2>/dev/null; then
                logger "USB 设备 $devname 已自动挂载到 /mnt/$devname"
            fi
        done
        ;;
esac
EOF
chmod +x files/etc/hotplug.d/block/10-automount
echo "✅ USB 自动挂载脚本完成"

# ===== 8. 创建 NPU 开机自启脚本 =====
echo ""
echo "创建 NPU 开机自启脚本..."
cat > files/etc/init.d/npu-optimize << 'EOF'
#!/bin/sh /etc/rc.common
# Airoha EN7581 NPU 优化脚本

START=98
STOP=20

start() {
    echo "启动 Airoha EN7581 NPU 优化..."
    sleep 3
    
    if [ -d "/proc/airoha" ]; then
        echo 1 > /proc/airoha/npu/enable 2>/dev/null && echo "  ✓ NPU 加速已启用"
        echo 1 > /proc/airoha/hnat/enable 2>/dev/null && echo "  ✓ 硬件 NAT 已启用"
    fi
    
    echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    echo "NPU 优化完成"
}

stop() {
    echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    if [ -d "/proc/airoha" ]; then
        echo 0 > /proc/airoha/npu/enable 2>/dev/null || true
    fi
}
EOF
chmod +x files/etc/init.d/npu-optimize
echo "✅ NPU 开机脚本完成"

# ===== 9. 创建欢迎信息 =====
echo ""
echo "创建欢迎信息..."
cat > files/etc/banner << 'EOF'
  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__|                   XG-040G-MD 小楼版

 -----------------------------------------------------
 版本: ImmortalWrt 25.12
 设备: XG-040G-MD (Airoha EN7581)
 功能: mwan3 + smartdns + zerotier + homeproxy + ksmbd + vsftpd-alt + transmission + upnp
 默认IP: 192.168.100.254
 -----------------------------------------------------
EOF
echo "✅ 欢迎信息完成"

# ===== 10. 创建防火墙优化规则 =====
echo ""
echo "创建防火墙优化规则..."
cat > files/etc/firewall.user << 'EOF'
# 自定义防火墙规则
echo bbr > /proc/sys/net/ipv4/tcp_congestion_control
echo 65536 > /proc/sys/net/netfilter/nf_conntrack_max
echo 30 > /proc/sys/net/netfilter/nf_conntrack_udp_timeout
echo 30 > /proc/sys/net/netfilter/nf_conntrack_icmp_timeout
exit 0
EOF
chmod +x files/etc/firewall.user
echo "✅ 防火墙优化规则完成"

echo ""
echo "========================================="
echo "new.sh 预配置脚本执行完成！"
echo "========================================="
echo "创建的文件列表："
find files -type f | sort | sed 's/^/  /'
echo ""
echo "总共创建了 $(find files -type f | wc -l) 个文件"
# ===== 添加 webd（轻量级 WebDAV）=====
echo "添加 webd..."
if [ ! -d "package/webd" ]; then
    # 创建 webd 目录
    mkdir -p package/webd/files
    
    # 下载 Makefile
    wget -O package/webd/Makefile https://raw.githubusercontent.com/openwrt/packages/master/net/webd/Makefile
    
    # 创建默认配置文件（可选）
    mkdir -p package/webd/files/etc/config
    cat > package/webd/files/etc/config/webd << 'EOF'
config webd 'main'
    option enabled '1'
    option port '5244'
    option root '/mnt'
    option auth 'admin:$1$yZ9jU7qL$k3F2mN8rX5vB9cW7'  # 默认密码: password
EOF
    
    # 创建 init.d 启动脚本
    mkdir -p package/webd/files/etc/init.d
    cat > package/webd/files/etc/init.d/webd << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1

start_service() {
    local enabled port root auth
    
    config_load webd
    config_get enabled main enabled
    config_get port main port 5244
    config_get root main root '/mnt'
    config_get auth main auth ''
    
    [ "$enabled" = "0" ] && return
    
    procd_open_instance
    procd_set_param command /usr/bin/webd
    [ -n "$port" ] && procd_append_param command -p "$port"
    [ -n "$root" ] && procd_append_param command -r "$root"
    [ -n "$auth" ] && procd_append_param command -a "$auth"
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
EOF
    chmod +x package/webd/files/etc/init.d/webd
    
    echo "✅ webd 添加完成"
fi


