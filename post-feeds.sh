#!/bin/bash
# post-feeds.sh - XG-040G-MD 小楼版后配置脚本
# 不带 PassWall

set -e

echo "========================================="
echo "开始执行 post-feeds.sh 后配置脚本"
echo "========================================="
echo "当前目录: $(pwd)"

# 检查是否在 openwrt 目录中
if [[ "$(basename "$PWD")" != "openwrt" ]]; then
    echo "错误: 不在 openwrt 目录中"
    exit 1
fi

# ===== 1. 安装 feeds =====
echo "安装 feeds..."
./scripts/feeds install -a
echo "✅ feeds 安装完成"

# ===== 2. 修复 vsftpd-alt 权限 =====
echo "修复 vsftpd-alt 权限..."
if [ -d "feeds/luci/applications/luci-app-vsftpd-alt" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-vsftpd-alt/root/etc/uci-defaults/
    echo "✅ vsftpd-alt 权限修复完成"
fi

# ===== 3. 修复 homeproxy 权限 =====
echo "修复 homeproxy 权限..."
if [ -d "feeds/luci/applications/luci-app-homeproxy" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-homeproxy/root/etc/uci-defaults/
    echo "✅ homeproxy 权限修复完成"
fi

# ===== 4. 修复主题权限 =====
echo "修复主题权限..."
if [ -d "feeds/luci/themes/luci-theme-argon" ]; then
    chmod -R 755 feeds/luci/themes/luci-theme-argon/root/etc/uci-defaults/
    echo "✅ argon 主题权限修复完成"
fi

if [ -d "feeds/luci/applications/luci-app-advancedplus" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-advancedplus/root/etc/uci-defaults/
    echo "✅ advancedplus 权限修复完成"
fi

# ===== 5. 重新生成 LuCI 索引 =====
echo "重新生成 LuCI 索引..."
if [ -d "feeds/luci" ]; then
    # 使用 feeds 命令重建索引
    ./scripts/feeds update -i
    echo "✅ LuCI 索引生成完成"
else
    echo "⚠️ feeds/luci 目录不存在，跳过索引生成"
fi

# ===== 6. 确保 iptables 模块完整 =====
echo "检查并创建缺失的依赖..."
mkdir -p files/etc/modules.d
cat > files/etc/modules.d/20-iptables-extra << 'EOF'
# 额外 iptables 模块
nf_conntrack
nf_conntrack_ipv4
nf_nat
EOF
echo "✅ 依赖检查完成"

echo "========================================="
echo "post-feeds.sh 后配置脚本执行完成！"
echo "========================================="
