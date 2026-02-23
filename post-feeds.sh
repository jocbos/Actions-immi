#!/bin/bash
# post-feeds.sh - XG-040G-MD 小楼版后配置脚本
# 适用于 immortalwrt 25.12 分支
# 执行时机: feeds 更新后

set -e  # 出错立即退出

echo "========================================="
echo "开始执行 post-feeds.sh 后配置脚本"
echo "========================================="

# 进入 openwrt 目录
cd openwrt || exit 1

# ===== 1. 安装 PassWall 相关包 =====
echo "安装 PassWall 相关包..."
./scripts/feeds install -a -p passwall_luci
./scripts/feeds install -a -p passwall_packages
./scripts/feeds install -a -p kenzo
./scripts/feeds install -a -p small
echo "✅ PassWall 包安装完成"

# ===== 2. 修复 vsftpd-alt 权限 =====
echo "修复 vsftpd-alt 权限..."
if [ -d "feeds/luci/applications/luci-app-vsftpd-alt" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-vsftpd-alt/root/etc/uci-defaults/
    echo "✅ vsftpd-alt 权限修复完成"
else
    echo "⚠️ luci-app-vsftpd-alt 未找到，跳过权限修复"
fi

# ===== 3. 修复 PassWall 权限 =====
echo "修复 PassWall 权限..."
if [ -d "feeds/luci/applications/luci-app-passwall" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-passwall/root/etc/uci-defaults/
    echo "✅ PassWall 权限修复完成"
fi

# ===== 4. 修复 homeproxy 权限 =====
echo "修复 homeproxy 权限..."
if [ -d "feeds/luci/applications/luci-app-homeproxy" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-homeproxy/root/etc/uci-defaults/
    echo "✅ homeproxy 权限修复完成"
fi

# ===== 5. 创建 NPU 开机自启脚本 =====
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
    if [ -f "/proc/airoha/npu/enable" ]; then
        echo 1 > /proc/airoha/npu/enable 2>/dev/null && echo "  ✓ NPU 加速已启用"
    fi
    
    # 启用硬件 NAT
    if [ -f "/proc/airoha/hnat/enable" ]; then
        echo 1 > /proc/airoha/hnat/enable 2>/dev/null && echo "  ✓ 硬件 NAT 已启用"
    fi
    
    # CPU 性能模式
    echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    
    echo "NPU 优化完成"
}

stop() {
    echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    echo 0 > /proc/airoha/npu/enable 2>/dev/null || true
}
EOF
chmod +x files/etc/init.d/npu-optimize
echo "✅ NPU 开机脚本创建完成"

# ===== 6. 修复主题权限 =====
echo "修复主题权限..."
if [ -d "feeds/luci/themes/luci-theme-argon" ]; then
    chmod -R 755 feeds/luci/themes/luci-theme-argon/root/etc/uci-defaults/
    echo "✅ argon 主题权限修复完成"
fi

if [ -d "feeds/luci/applications/luci-app-advancedplus" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-advancedplus/root/etc/uci-defaults/
    echo "✅ advancedplus 权限修复完成"
fi

# ===== 7. 重新生成 LuCI 索引 =====
echo "重新生成 LuCI 索引..."
if [ -d "feeds/luci" ]; then
    (cd feeds/luci && ./contrib/package/luci.mk)
    echo "✅ LuCI 索引生成完成"
fi

# ===== 8. 检查并创建缺失的依赖 =====
echo "检查并创建缺失的依赖..."

# 确保 iptables 模块完整
mkdir -p files/etc/modules.d
cat > files/etc/modules.d/20-iptables-extra << 'EOF'
# 额外 iptables 模块
nf_conntrack
nf_conntrack_ipv4
nf_nat
EOF

# 创建 USB 自动挂载脚本
mkdir -p files/etc/hotplug.d/block
cat > files/etc/hotplug.d/block/10-automount << 'EOF'
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
chmod +x files/etc/hotplug.d/block/10-automount

echo "✅ 依赖检查完成"

echo "========================================="
echo "post-feeds.sh 后配置脚本执行完成！"
echo "========================================="

# 显示安装状态
echo "已安装的 feeds 列表："
./scripts/feeds list | grep -E "passwall|kenzo|small|homeproxy" || true
