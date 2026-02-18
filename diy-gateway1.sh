#!/bin/bash
# XG-040G-MD 全能版 DIY脚本

# ===== 1. 添加软件源 =====
sed -i '/kenzo/d' feeds.conf.default 2>/dev/null || true
sed -i '/small/d' feeds.conf.default 2>/dev/null || true
echo "src-git kenzo https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default
echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default

# 下载 sirboy 主题到 package 目录
cd package
[ -d "luci-theme-kucat" ] || git clone --depth 1 https://github.com/sirpdboy/luci-theme-kucat.git
[ -d "luci-app-advancedplus" ] || git clone --depth 1 https://github.com/sirpdboy/luci-app-advancedplus.git
cd ..

# ===== 2. 系统基础配置 =====
sed -i 's/192.168.1.1/192.168.100.254/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/XG-040G-MD/g' package/base-files/files/bin/config_generate
sed -i 's/UTC/Asia/Shanghai/g' package/base-files/files/bin/config_generate

# ===== 3. 网络优化参数（开启BBR）=====
mkdir -p files/etc/sysctl.d
cat > files/etc/sysctl.d/99-custom.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.netfilter.nf_conntrack_max = 65536
EOF

# ===== 4. USB自动挂载 =====
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
                fi
                break
            fi
            sleep 1
        done
        ;;
    remove)
        MOUNT_POINT="/mnt/$(basename $DEVNAME)"
        umount -l $MOUNT_POINT 2>/dev/null
        rm -f /mnt/usb_disk 2>/dev/null
        ;;
esac
EOF
chmod +x files/etc/hotplug.d/block/20-automount

# ===== 5. vsftpd配置 =====
mkdir -p files/etc/config
cat > files/etc/config/vsftpd <<'EOF'
config vsftpd 'config'
	option enabled '1'
	option port '21'
	option pasv_min_port '30000'
	option pasv_max_port '30100'
	option anonymous_enable '1'
	option local_enable '1'
	option write_enable '1'
	option anon_root '/mnt/usb_disk'
	option local_root '/mnt/usb_disk'
EOF

# ===== 6. Samba4配置 =====
mkdir -p files/etc/samba
cat > files/etc/samba/smb.conf.template <<'EOF'
[global]
netbios name = XG-040G-MD
server string = XG-040G-MD
workgroup = WORKGROUP
security = user
guest account = nobody
map to guest = Bad User

[USB_Share]
path = /mnt/usb_disk
guest ok = yes
read only = no
create mask = 0777
directory mask = 0777
EOF

# ===== 7. Transmission配置 =====
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
    "peer-port": 51413
}
EOF

# 创建目录
mkdir -p files/mnt/usb_disk/{downloads,incomplete,torrents}

# ===== 8. 防火墙规则 =====
mkdir -p files/etc
cat > files/etc/firewall.user <<'EOF'
#!/bin/sh
# 开启转发
echo 1 > /proc/sys/net/ipv4/ip_forward

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

# ===== 9. 版本信息 =====
mkdir -p files/etc
cat > files/etc/xg040gmd_version <<EOF
XG-040G-MD 老楼版
编译时间: $(date +"%Y-%m-%d %H:%M:%S")

功能特性:
- 防火墙: 老版 iptables
- 网络核心: mwan3 + SmartDNS + ZeroTier + HomeProxy
- 文件共享: Samba4 + vsftpd
- 下载服务: Transmission
- 网络加速: Shortcut-FE + BBR
- 美化主题: kucat + advancedplus
EOF

# ===== 10. post-feeds脚本 =====
cat > $GITHUB_WORKSPACE/post-feeds.sh <<'EOF'
#!/bin/bash
if [ -f "feeds/luci/collections/luci/Makefile" ]; then
    sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' feeds/luci/collections/luci/Makefile
fi
EOF
chmod +x $GITHUB_WORKSPACE/post-feeds.sh

# ===== 11. 生成配置 =====
make defconfig

echo "=========================================="
echo "✅ XG-040G-MD 全能版 DIY脚本执行完成"
echo "=========================================="
echo "📋 包含功能："
echo "   - mwan3 + SmartDNS + ZeroTier + HomeProxy"
echo "   - Samba4 + vsftpd"
echo "   - Transmission"
echo "   - Shortcut-FE + BBR"
echo "   - 老版 iptables"
echo "=========================================="
