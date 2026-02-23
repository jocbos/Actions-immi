#!/bin/bash
# post-feeds.sh - XG-040G-MD 小楼版后配置脚本
# 包含 Go 语言修复

set -e

echo "========================================="
echo "开始执行 post-feeds.sh 后配置脚本"
echo "========================================="

# 进入 openwrt 目录
cd openwrt || exit 1

# ===== 1. 修复 Go 语言版本（解决 Makefile 错误）=====
echo "升级 Go 语言版本..."
if [ -d "feeds/packages/lang/golang" ]; then
    rm -rf feeds/packages/lang/golang
fi
git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 22.x feeds/packages/lang/golang
echo "✅ Go 版本升级完成"

# ===== 2. 安装 small_package 的包 =====
echo "安装 small_package 的包..."
./scripts/feeds install -a -p small_package
echo "✅ small_package 包安装完成"

# ===== 3. 修复 vsftpd-alt 权限 =====
echo "修复 vsftpd-alt 权限..."
if [ -d "feeds/luci/applications/luci-app-vsftpd-alt" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-vsftpd-alt/root/etc/uci-defaults/
    echo "✅ vsftpd-alt 权限修复完成"
fi

# ===== 4. 修复 PassWall 权限 =====
echo "修复 PassWall 权限..."
if [ -d "feeds/luci/applications/luci-app-passwall" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-passwall/root/etc/uci-defaults/
    echo "✅ PassWall 权限修复完成"
fi

# ===== 5. 修复 homeproxy 权限 =====
echo "修复 homeproxy 权限..."
if [ -d "feeds/luci/applications/luci-app-homeproxy" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-homeproxy/root/etc/uci-defaults/
    echo "✅ homeproxy 权限修复完成"
fi

# ===== 6. 修复 small_package 中包的权限 =====
echo "修复 small_package 中包的权限..."
find feeds/small_package -name "luci-app-*" -type d 2>/dev/null | while read dir; do
    if [ -d "$dir/root/etc/uci-defaults" ]; then
        chmod -R 755 "$dir/root/etc/uci-defaults/"
        echo "  ✅ 修复: $(basename $dir)"
    fi
done

# ===== 7. 修复主题权限 =====
echo "修复主题权限..."
if [ -d "feeds/luci/themes/luci-theme-argon" ]; then
    chmod -R 755 feeds/luci/themes/luci-theme-argon/root/etc/uci-defaults/
    echo "✅ argon 主题权限修复完成"
fi

if [ -d "feeds/luci/applications/luci-app-advancedplus" ]; then
    chmod -R 755 feeds/luci/applications/luci-app-advancedplus/root/etc/uci-defaults/
    echo "✅ advancedplus 权限修复完成"
fi

# ===== 8. 重新生成 LuCI 索引 =====
echo "重新生成 LuCI 索引..."
if [ -d "feeds/luci" ]; then
    (cd feeds/luci && ./contrib/package/luci.mk)
    echo "✅ LuCI 索引生成完成"
fi

# ===== 9. 确保 iptables 模块完整 =====
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

# 显示安装状态
echo "已安装的 feeds 列表："
./scripts/feeds list | grep -E "small_package|homeproxy" || true
