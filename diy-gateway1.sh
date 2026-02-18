#!/bin/bash
# XG-040G-MD 老楼版 DIY脚本
# 功能: mwan3 + smartdns + zerotier + homeproxy + ksmbd + vsftpd + transmission

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
- 下载服务: Transmission
- 网络加速: Shortcut-FE + BBR
- 美化主题: kucat + advancedplus

访问方式:
- 路由器: http://192.168.100.254
- Transmission: http://192.168.100.254:9091
- FTP: ftp://192.168.100.254
- SMB: \\\\192.168.100.254\\USB_Share
EOF

# ===== 11. 创建 post-feeds 脚本（解决冲突）=====
cat > $GITHUB_WORKSPACE/post-feeds.sh <<'EOF'
#!/bin/bash
echo "=========================================="
echo "运行 post-feeds 脚本 - 解决包冲突"
echo "=========================================="

# 1. 修改默认主题为 kucat
if [ -f "feeds/luci/collections/luci/Makefile" ]; then
    sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' feeds/luci/collections/luci/Makefile
    echo "✅ 主题修改成功"
else
    echo "✅ 主题已在 package 目录"
fi

# 2. 解决 transmission-web 和 transmission-web-control 的冲突
echo "🔧 检查 Transmission 包冲突..."

# 方法一：如果两个包都存在，删除 web-control 的冲突文件
if [ -d "feeds/packages/transmission-web-control" ] && [ -d "feeds/packages/transmission-web" ]; then
    echo "检测到 transmission-web 和 transmission-web-control 同时存在"
    
    # 删除 web-control 的 index.html，避免覆盖
    if [ -f "feeds/packages/transmission-web-control/files/index.html" ]; then
        rm -f feeds/packages/transmission-web-control/files/index.html
        echo "✅ 已删除 transmission-web-control 的 index.html 文件"
    fi
    
    # 或者重命名 web-control 的目录，让系统只使用 transmission-web
    # mv feeds/packages/transmission-web-control feeds/packages/transmission-web-control.disabled
    # echo "✅ 已禁用 transmission-web-control"
fi

# 方法二：确保 transmission-web 的 index.html 存在
if [ -d "feeds/packages/transmission-web" ]; then
    if [ ! -f "feeds/packages/transmission-web/files/index.html" ]; then
        echo "创建默认的 transmission-web index.html"
        mkdir -p feeds/packages/transmission-web/files
        cat > feeds/packages/transmission-web/files/index.html <<'INNEREOF'
<!DOCTYPE html>
<html>
<head><meta http-equiv="refresh" content="0;url=/transmission/web/"></head>
<body>Redirecting to Transmission...</body>
</html>
INNEREOF
    fi
    echo "✅ transmission-web 已就绪"
fi

# 3. 检查是否有其他潜在冲突
echo "🔧 检查其他潜在包冲突..."

# 查找可能的重复文件
find ./feeds/packages -name "*.conflict" -type f -delete 2>/dev/null || true

echo "=========================================="
echo "✅ post-feeds 脚本执行完成"
echo "=========================================="
EOF

chmod +x $GITHUB_WORKSPACE/post-feeds.sh

# ===== 12. 修改 .config 确保 transmission-web-control 被禁用 =====
echo "🔧 确保 transmission-web-control 被禁用..."
cat >> .config <<'EOF'
# 禁用 transmission-web-control 避免冲突
# CONFIG_PACKAGE_transmission-web-control is not set
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
echo "   - 下载服务: Transmission (已处理包冲突)"
echo "   - 美化主题: kucat"
echo "=========================================="
