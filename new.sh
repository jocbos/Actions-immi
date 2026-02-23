#!/bin/bash
# new.sh - XG-040G-MD 小楼版预配置脚本
# 适用于 immortalwrt 25.12 分支
# 执行时机: feeds 更新前

set -e  # 出错立即退出

echo "========================================="
echo "开始执行 new.sh 预配置脚本"
echo "========================================="
echo "当前目录: $(pwd)"

# ===== 1. 备份原 feeds.conf.default =====
echo "备份原 feeds.conf.default..."
if [ -f "feeds.conf.default" ]; then
    cp feeds.conf.default feeds.conf.default.bak-$(date +%Y%m%d%H%M%S)
    echo "✅ 已备份原 feeds.conf.default"
fi

# ===== 2. 定义要添加的软件源 =====
declare -a NEW_FEEDS=(
    "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main"
    "src-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main"
    "src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master"
    "src-git small https://github.com/kenzok8/small.git;master"
    "src-git immortalwrt_luci https://github.com/immortalwrt/luci.git;openwrt-21.02"
    "src-git immortalwrt_packages https://github.com/immortalwrt/packages.git;openwrt-21.02"
)

# ===== 3. 添加软件源（去重）=====
echo ""
echo "添加第三方软件源（去重）..."

for feed in "${NEW_FEEDS[@]}"; do
    # 提取源名称（src-git 后面的第一个词）
    feed_name=$(echo "$feed" | awk '{print $2}')
    
    # 检查是否已存在
    if ! grep -q "^src-git $feed_name " feeds.conf.default 2>/dev/null; then
        echo "$feed" >> feeds.conf.default
        echo "✅ 添加源: $feed_name"
    else
        echo "⏭️ 源已存在，跳过: $feed_name"
    fi
done

echo ""
echo "✅ 软件源添加完成"
echo "最终 feeds.conf.default 内容:"
echo "----------------------------------------"
cat feeds.conf.default
echo "----------------------------------------"

# ===== 4. 创建自定义文件目录 =====
echo ""
echo "创建自定义文件目录..."
mkdir -p files/etc/uci-defaults
mkdir -p files/etc/init.d
mkdir -p files/etc/sysctl.d
mkdir -p files/etc/modules.d
mkdir -p files/etc/hotplug.d/block
mkdir -p files/root
echo "✅ 目录创建完成"

# ===== 5. 设置默认IP地址 =====
echo ""
echo "设置默认IP为 192.168.100.254..."
cat > files/etc/uci-defaults/99-ip-set << 'EOF'
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
chmod +x files/etc/uci-defaults/99-ip-set
echo "✅ 默认IP设置完成"

# ===== 6. 创建 NPU 驱动加载配置 =====
echo ""
echo "配置 NPU 驱动加载..."
cat > files/etc/modules.d/10-airoha-npu << 'EOF'
# Airoha EN7581 NPU 驱动
mtk_hnat
mtk_npu
EOF
echo "✅ NPU 配置完成"

# ===== 7. 创建系统优化配置 =====
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

# ===== 8. 创建 USB 自动挂载脚本 =====
echo ""
echo "创建 USB 自动挂载脚本..."
cat > files/etc/hotplug.d/block/10-automount << 'EOF'
#!/bin/sh
# USB 自动挂载脚本

case "$ACTION" in
    add)
        # 等待设备初始化
        sleep 2
        
        # 遍历所有块设备
        for device in /sys/block/sd*; do
            [ -d "$device" ] || continue
            devname=$(basename "$device")
            
            # 检查是否已经是挂载点
            if mount | grep -q "/dev/$devname"; then
                continue
            fi
            
            # 创建挂载点并挂载
            mkdir -p "/mnt/$devname"
            if mount "/dev/$devname" "/mnt/$devname" 2>/dev/null; then
                logger "USB 设备 $devname 已自动挂载到 /mnt/$devname"
            fi
        done
        ;;
    remove)
        logger "USB 设备已移除"
        ;;
esac
EOF
chmod +x files/etc/hotplug.d/block/10-automount
echo "✅ USB 自动挂载脚本完成"

# ===== 9. 创建 NPU 开机自启脚本 =====
echo ""
echo "创建 NPU 开机自启脚本..."
cat > files/etc/init.d/npu-optimize << 'EOF'
#!/bin/sh /etc/rc.common
# Airoha EN7581 NPU 优化脚本

START=98
STOP=20

start() {
    echo "启动 Airoha EN7581 NPU 优化..."
    
    # 等待系统完全启动
    sleep 3
    
    # 启用 NPU 硬件加速
    if [ -d "/proc/airoha" ]; then
        echo 1 > /proc/airoha/npu/enable 2>/dev/null && echo "  ✓ NPU 加速已启用"
        echo 1 > /proc/airoha/hnat/enable 2>/dev/null && echo "  ✓ 硬件 NAT 已启用"
    fi
    
    # CPU 性能模式
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

# ===== 10. 创建欢迎信息 =====
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
 功能: PassWall + HomeProxy + mwan3 + ksmbd
 默认IP: 192.168.100.254
 用户名: root (无密码)
 -----------------------------------------------------
EOF
echo "✅ 欢迎信息完成"

# ===== 11. 创建防火墙优化规则 =====
echo ""
echo "创建防火墙优化规则..."
cat > files/etc/firewall.user << 'EOF'
# 自定义防火墙规则

# 开启 BBR
echo bbr > /proc/sys/net/ipv4/tcp_congestion_control

# 优化 conntrack
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
echo "========================================="
