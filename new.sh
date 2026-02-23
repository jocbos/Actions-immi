#!/bin/bash
# new.sh - XG-040G-MD 小楼版预配置脚本

set -e

echo "========================================="
echo "开始执行 new.sh 预配置脚本"
echo "========================================="

# ===== 1. 备份原 feeds.conf.default =====
if [ -f "feeds.conf.default" ]; then
    cp feeds.conf.default feeds.conf.default.bak-$(date +%Y%m%d%H%M%S)
    echo "✅ 已备份原 feeds.conf.default"
fi

# ===== 2. 清理可能存在的重复源 =====
echo "清理 feeds.conf.default 中的重复源..."

# 创建一个临时文件
> feeds.conf.default.tmp

# 逐行读取原文件，去重
if [ -f "feeds.conf.default.bak-*" ]; then
    # 读取备份文件
    cat feeds.conf.default.bak-* | while read line; do
        # 如果是空行或注释，直接保留
        if [[ -z "$line" ]] || [[ "$line" == \#* ]]; then
            echo "$line" >> feeds.conf.default.tmp
            continue
        fi
        
        # 提取源名称
        if [[ "$line" == src-git* ]]; then
            feed_name=$(echo "$line" | awk '{print $2}')
            # 检查是否已经添加过
            if ! grep -q "^src-git $feed_name " feeds.conf.default.tmp; then
                echo "$line" >> feeds.conf.default.tmp
            fi
        else
            echo "$line" >> feeds.conf.default.tmp
        fi
    done
fi

# 替换原文件
mv feeds.conf.default.tmp feeds.conf.default
echo "✅ 源清理完成"

# ===== 3. 定义要添加的软件源 =====
declare -a NEW_FEEDS=(
    "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main"
    "src-git passwall_luci https://github.com/xiaorouji/openwrt-passwall.git;main"
    "src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master"
    "src-git small https://github.com/kenzok8/small.git;master"
)

# ===== 4. 添加软件源（去重）=====
echo ""
echo "添加第三方软件源（去重）..."

for feed in "${NEW_FEEDS[@]}"; do
    feed_name=$(echo "$feed" | awk '{print $2}')
    
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
cat feeds.conf.default

# ===== 5. 创建自定义文件目录 =====
echo ""
echo "创建自定义文件目录..."
mkdir -p files/etc/uci-defaults
mkdir -p files/etc/init.d
mkdir -p files/etc/sysctl.d
mkdir -p files/etc/modules.d
mkdir -p files/etc/hotplug.d/block
mkdir -p files/root
echo "✅ 目录创建完成"

# ===== 6. 设置默认IP地址 =====
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

# ===== 7. 创建 NPU 驱动加载配置 =====
echo ""
echo "配置 NPU 驱动加载..."
cat > files/etc/modules.d/10-airoha-npu << 'EOF'
mtk_hnat
mtk_npu
EOF
echo "✅ NPU 配置完成"

# ===== 8. 创建系统优化配置 =====
echo ""
echo "创建系统优化配置..."
cat > files/etc/sysctl.d/99-optimize.conf << 'EOF'
net.core.rmem_max = 262144
net.core.wmem_max = 262144
net.ipv4.tcp_rmem = 16384 43689 262144
net.ipv4.tcp_wmem = 16384 43689 262144
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
echo "✅ 系统优化配置完成"

# ===== 9. 创建 USB 自动挂载脚本 =====
echo ""
echo "创建 USB 自动挂载脚本..."
cat > files/etc/hotplug.d/block/10-automount << 'EOF'
#!/bin/sh
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

# ===== 10. 创建 NPU 开机自启脚本 =====
echo ""
echo "创建 NPU 开机自启脚本..."
cat > files/etc/init.d/npu-optimize << 'EOF'
#!/bin/sh /etc/rc.common
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

# ===== 11. 创建欢迎信息 =====
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
 -----------------------------------------------------
EOF
echo "✅ 欢迎信息完成"

echo ""
echo "========================================="
echo "new.sh 预配置脚本执行完成！"
echo "========================================="
