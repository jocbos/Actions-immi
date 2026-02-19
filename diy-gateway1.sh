#!/bin/bash
# XG-040G-MD 老楼版 DIY脚本
# 功能: mwan3 + smartdns + zerotier + homeproxy + ksmbd + vsftpd + transmission
# 方案: 保留 transmission-web-control，删除自带的 transmission-web

# ===== 1. 添加软件源 =====
sed -i '/kenzo/d' feeds.conf.default 2>/dev/null || true
sed -i '/small/d' feeds.conf.default 2>/dev/null || true

echo "src-git kenzo https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default
echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default

# 直接下载 sirboy 主题到 package 目录
cd package
[ -d "luci-theme-kucat" ] || git clone --depth 1 https://github.com/sirpdboy/luci-theme-kucat.git
[ -d "luci-app-advancedplus" ] || git clone --depth 1 https://github.com/sirpdboy/luci-app-advancedplus.git
cd ..

# ===== 2. 系统基础配置 =====
sed -i 's/192.168.1.1/192.168.100.254/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/XG-040G-MD/g' package/base-files/files/bin/config_generate
sed -i 's/UTC/Asia/Shanghai/g' package/base-files/files/bin/config_generate

# ===== 3. 内核网络优化参数 =====
mkdir -p files/etc/sysctl.d
cat > files/etc/sysctl.d/99-custom.conf <<'EOF'
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.netfilter.nf_conntrack_max = 65536
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_icmp_timeout = 30
vm.min_free_kbytes = 65536
vm.vfs_cache_pressure = 50
EOF

# ===== 4. USB 自动挂载脚本 =====
mkdir -p files/etc/hotplug.d/block
cat > files/etc/hotplug.d/block/20-automount <<'EOF'
#!/bin/sh
case "$ACTION" in
    add)
        for i in 1 2 3 4 5; do
            if [ -e "/dev/$DEVNAME" ]; then
                MOUNT_POINT="/mnt/$(basename $DEVNAME)"
                mkdir -p $MOUNT_POINT
                mount -t auto /dev/$DEVNAME $MOUNT_POINT 2>/dev/null
                
                if mountpoint -q $MOUNT_POINT; then
                    ln -sf $MOUNT_POINT /mnt/usb_disk 2>/dev/null
                    echo "$(date): USB设备 $DEVNAME 挂载到 $MOUNT_POINT" >> /tmp/usb-mount.log
                fi
                break
            fi
            sleep 1
        done
        ;;
    remove)
        MOUNT_POINT="/mnt/$(basename $DEVNAME)"
        if mountpoint -q $MOUNT_POINT; then
            umount -l $MOUNT_POINT 2>/dev/null
            rmdir $MOUNT_POINT 2>/dev/null
            rm -f /mnt/usb_disk 2>/dev/null
        fi
        ;;
esac
EOF
chmod +x files/etc/hotplug.d/block/20-automount

# ===== 5. ksmbd 默认配置 =====
mkdir -p files/etc/config
cat > files/etc/config/ksmbd <<'EOF'
config globals
	option workgroup 'WORKGROUP'
	option server_string 'XG-040G-MD'
	option interfaces 'br-lan'
	option bind_interfaces_only '1'
	option load_printers '0'
	option disable_smb1 '1'

config share
	option name 'USB_Share'
	option path '/mnt/usb_disk'
	option browseable 'yes'
	option read_only 'no'
	option guest_ok 'yes'
	option create_mask '0777'
	option dir_mask '0777'
EOF

# ===== 6. vsftpd 默认配置 =====
mkdir -p files/etc/config
cat > files/etc/config/vsftpd <<'EOF'
config vsftpd 'config'
	option enabled '1'
	option port '21'
	option pasv_min_port '30000'
	option pasv_max_port '30100'
	option pasv_promiscuous '1'
	option background '1'
	option check_shell '0'
	option anonymous_enable '1'
	option local_enable '1'
	option write_enable '1'
	option anon_upload_enable '1'
	option anon_mkdir_write_enable '1'
	option anon_other_write_enable '1'
	option anon_root '/mnt/usb_disk'
	option local_root '/mnt/usb_disk'
	option hide_ids '1'
	option ls_recurse_enable '1'
	option max_clients '10'
	option max_per_ip '3'
	option use_logwtmp '0'
	option session_support '0'
	option seccomp_sandbox '0'
EOF

# ===== 7. Transmission 默认配置 =====
mkdir -p files/etc/config
mkdir -p files/etc/transmission
cat > files/etc/transmission/settings.json <<'EOF'
{
    "download-dir": "/mnt/usb_disk/downloads",
    "incomplete-dir": "/mnt/usb_disk/incomplete",
    "watch-dir": "/mnt/usb_disk/torrents",
    "rpc-bind-address": "0.0.0.0",
    "rpc-port": 9091,
    "rpc-whitelist": "127.0.0.1,192.168.*.*",
    "rpc-whitelist-enabled": true,
    "umask": 18,
    "peer-port": 51413,
    "rpc-seccomp-enabled": false
}
EOF

# 创建目录
mkdir -p files/mnt/usb_disk/{downloads,incomplete,torrents}

# ===== 8. 启动脚本 =====
mkdir -p files/etc/init.d
cat > files/etc/init.d/transmission_setup <<'EOF'
#!/bin/sh /etc/rc.common
START=95
boot() {
    sleep 5
    if [ -d "/mnt/usb_disk" ]; then
        mkdir -p /mnt/usb_disk/downloads
        mkdir -p /mnt/usb_disk/incomplete
        mkdir -p /mnt/usb_disk/torrents
        chmod 777 /mnt/usb_disk/downloads
        chmod 777 /mnt/usb_disk/incomplete
        chmod 777 /mnt/usb_disk/torrents
    fi
}
EOF
chmod +x files/etc/init.d/transmission_setup

# ===== 9. 防火墙自定义规则 =====
mkdir -p files/etc
cat > files/etc/firewall.user <<'EOF'
#!/bin/sh
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true

iptables -A INPUT -i br-lan -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 开放端口
iptables -A INPUT -p tcp --dport 22 -j ACCEPT   # SSH
iptables -A INPUT -p tcp --dport 80 -j ACCEPT   # Web
iptables -A INPUT -p tcp --dport 443 -j ACCEPT  # HTTPS
iptables -A INPUT -p tcp --dport 445 -j ACCEPT  # SMB
iptables -A INPUT -p tcp --dport 139 -j ACCEPT  # SMB NetBIOS
iptables -A INPUT -p udp --dport 137 -j ACCEPT  # SMB NetBIOS
iptables -A INPUT -p udp --dport 138 -j ACCEPT  # SMB NetBIOS
iptables -A INPUT -p tcp --dport 21 -j ACCEPT   # FTP
iptables -A INPUT -p tcp --dport 30000:30100 -j ACCEPT  # FTP被动
iptables -A INPUT -p tcp --dport 9091 -j ACCEPT # Transmission Web
iptables -A INPUT -p tcp --dport 51413 -j ACCEPT # Transmission DHT
iptables -A INPUT -p udp --dport 51413 -j ACCEPT # Transmission DHT

exit 0
EOF
chmod +x files/etc/firewall.user

# ===== 10. 版本信息 =====
mkdir -p files/etc
cat > files/etc/xg040gmd_version <<EOF
XG-040G-MD 老楼版
编译时间: $(date +"%Y-%m-%d %H:%M:%S")

功能特性:
- 防火墙: 老版 iptables
- 网络核心: mwan3 + SmartDNS + ZeroTier + HomeProxy
- 文件共享: ksmbd (SMB) + vsftpd (FTP)
- 下载服务: Transmission (web-control 美化版)
- 网络加速: Shortcut-FE + BBR
- 美化主题: kucat + advancedplus

访问方式:
- 路由器: http://192.168.100.254
- Transmission: http://192.168.100.254:9091 (web-control美化界面)
- FTP: ftp://192.168.100.254
- SMB: \\\\192.168.100.254\\USB_Share
EOF

# ===== 11. 创建 post-feeds 脚本（保留 web-control，删除 web）=====
cat > $GITHUB_WORKSPACE/post-feeds.sh <<'EOF'
#!/bin/bash
echo "=========================================="
echo "运行 post-feeds 脚本 - 保留 web-control"
echo "=========================================="

# 1. 修改默认主题为 kucat
if [ -f "feeds/luci/collections/luci/Makefile" ]; then
    sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' feeds/luci/collections/luci/Makefile
    echo "✅ 主题修改成功"
fi

# 2. 删除自带的 transmission-web，保留 web-control
echo "🔧 删除自带的 transmission-web..."

# 在 feeds 目录中删除 transmission-web
if [ -d "feeds/packages/transmission-web" ]; then
    echo "删除 feeds/packages/transmission-web"
    rm -rf feeds/packages/transmission-web
    echo "✅ 已删除 transmission-web"
fi

# 在 package/feeds 目录中删除
if [ -d "package/feeds/packages/transmission-web" ]; then
    echo "删除 package/feeds/packages/transmission-web"
    rm -rf package/feeds/packages/transmission-web
fi

# 3. 确保 web-control 存在
if [ -d "feeds/packages/transmission-web-control" ]; then
    echo "✅ transmission-web-control 已就绪"
else
    echo "⚠️ transmission-web-control 不存在，尝试从 kenzo 源获取"
    # 如果不存在，可能需要额外处理，但通常 kenzo 源会有
fi

# 4. 删除所有对 transmission-web 的引用（但保留 web-control）
echo "🔧 清理 Makefile 中的引用..."
find ./feeds -name "Makefile" -exec grep -l "transmission-web" {} \; | while read file; do
    # 确保不要误删 web-control 的引用
    if ! grep -q "transmission-web-control" "$file"; then
        echo "删除 $file 中的 transmission-web 引用"
        sed -i '/transmission-web/d' "$file"
    fi
done

# 5. 确保 transmission 的 Web 目录指向 web-control
mkdir -p files/usr/share/transmission
cat > files/usr/share/transmission/index.html <<'INNEREOF'
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="refresh" content="0;url=/transmission/web-control/">
    <title>Transmission Web Control</title>
</head>
<body>
    <p>正在跳转到 Transmission Web Control...</p>
</body>
</html>
INNEREOF
echo "✅ 已设置 Web 跳转到 web-control"

echo "=========================================="
echo "✅ post-feeds 脚本执行完成"
echo "=========================================="
EOF

chmod +x $GITHUB_WORKSPACE/post-feeds.sh

# ===== 12. 修改 .config 确保 transmission-web 被禁用，web-control 启用 =====
echo "🔧 配置 Transmission 包选择..."
cat >> .config <<'EOF'
# 禁用自带的 transmission-web
# CONFIG_PACKAGE_transmission-web is not set

# 启用 web-control 美化版
CONFIG_PACKAGE_transmission-web-control=y

# 确保其他 Transmission 组件正常
CONFIG_PACKAGE_transmission-daemon=y
CONFIG_PACKAGE_luci-app-transmission=y
CONFIG_PACKAGE_luci-i18n-transmission-zh-cn=y
EOF

# ===== 13. 生成配置 =====
make defconfig

# ===== 14. 完成信息 =====
echo "=========================================="
echo "✅ XG-040G-MD 老楼版 DIY脚本执行完成"
echo "=========================================="
echo "📋 配置摘要："
echo "   - 默认IP: 192.168.100.254"
echo "   - 防火墙: 老版 iptables"
echo "   - USB挂载: /mnt/usb_disk"
echo "   - 文件共享: ksmbd + vsftpd"
echo "   - 下载服务: Transmission (web-control美化版)"
echo "   - 美化主题: kucat"
echo "=========================================="
