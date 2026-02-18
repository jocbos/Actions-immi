#!/bin/bash
# XG-040G-MD 网关固件 DIY 脚本
# 功能: 老版firewall + USB自动挂载 + ksmbd/vsftpd + Aria2 + sirboy主题

# ===== 1. 添加软件源 =====
sed -i '/kenzo/d' feeds.conf.default 2>/dev/null || true
sed -i '/small/d' feeds.conf.default 2>/dev/null || true
sed -i '/sirpdboy/d' feeds.conf.default 2>/dev/null || true

echo "src-git kenzo https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default
echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default
echo "src-git sirpdboy https://github.com/sirpdboy/sirpdboy-package" >> feeds.conf.default

# ===== 2. 系统基础配置 =====
sed -i 's/192.168.1.1/192.168.100.254/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/XG-040G-MD/g' package/base-files/files/bin/config_generate
sed -i 's/UTC/Asia/Shanghai/g' package/base-files/files/bin/config_generate
sed -i 's/luci-theme-bootstrap/luci-theme-kucat/g' feeds/luci/collections/luci/Makefile

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

# ===== 7. Aria2 默认配置 =====
mkdir -p files/etc/config
cat > files/etc/config/aria2 <<'EOF'
config aria2 'main'
	option enabled '1'
	option enable_rpc '1'
	option rpc_listen_all '1'
	option rpc_port '6800'
	option dir '/mnt/usb_disk/downloads'
	option input_file '/etc/aria2/aria2.session'
	option disk_cache '8'
	option continue '1'
	option max_concurrent_downloads '5'
	option max_connection_per_server '5'
	option min_split_size '5M'
	option split '5'
	option bt_enable_lpd '1'
	option bt_max_peers '55'
	option bt_tracker 'udp://tracker.opentrackr.org:1337/announce,udp://tracker.openbittorrent.com:6969/announce,udp://tracker.coppersurfer.tk:6969/announce'
	option enable_dht '1'
	option enable_peer_exchange '1'
	option max_download_limit '0'
	option max_upload_limit '0'
	option umask '022'
	option auto_save_interval '60'
	option save_session_interval '60'
EOF

mkdir -p files/mnt/usb_disk/downloads
mkdir -p files/etc/aria2
touch files/etc/aria2/aria2.session

# ===== 8. AriaNg Web界面 =====
mkdir -p files/www/ariang
cat > files/www/ariang/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>AriaNg</title>
    <style>
        body { margin: 0; padding: 0; height: 100vh; overflow: hidden; }
        iframe { width: 100%; height: 100%; border: none; }
    </style>
</head>
<body>
    <iframe src="https://ariang.mayswind.net/latest"></iframe>
</body>
</html>
EOF

# ===== 9. 启动脚本 =====
mkdir -p files/etc/init.d
cat > files/etc/init.d/aria2_setup <<'EOF'
#!/bin/sh /etc/rc.common
START=95
boot() {
    sleep 5
    if [ -d "/mnt/usb_disk" ]; then
        mkdir -p /mnt/usb_disk/downloads
        chmod 777 /mnt/usb_disk/downloads
        touch /etc/aria2/aria2.session
    fi
}
EOF
chmod +x files/etc/init.d/aria2_setup

# ===== 10. 防火墙自定义规则 =====
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
iptables -A INPUT -p tcp --dport 21 -j ACCEPT   # FTP
iptables -A INPUT -p tcp --dport 30000:30100 -j ACCEPT  # FTP被动
iptables -A INPUT -p tcp --dport 6800 -j ACCEPT # Aria2 RPC
iptables -A INPUT -p tcp --dport 6881 -j ACCEPT # DHT
iptables -A INPUT -p udp --dport 6881 -j ACCEPT # DHT UDP

exit 0
EOF
chmod +x files/etc/firewall.user

# ===== 11. 版本信息 =====
mkdir -p files/etc
cat > files/etc/xg040gmd_version <<EOF
XG-040G-MD  (老楼版)
编译时间: $(date +"%Y-%m-%d %H:%M:%S")

功能特性:
- 防火墙: 老版 iptables (兼容mwan3)
- 文件共享: ksmbd (SMB) + vsftpd (FTP)
- 下载服务: Aria2 + AriaNg
- 美化主题: kucat + advancedplus
- 网络核心: mwan3 + SmartDNS + HomeProxy
- 网络加速: Shortcut-FE + BBR

访问方式:
- 路由器: http://192.168.100.254
- AriaNg下载: http://192.168.100.254/ariang
- FTP: ftp://192.168.100.254
- SMB: \\\\192.168.100.254\\USB_Share
EOF

# ===== 12. 生成配置 =====
make defconfig

# ===== 13. 完成信息 =====
echo "=========================================="
echo "✅ XG-040G-MD DIY 脚本执行完成"
echo "=========================================="
echo "📋 配置摘要："
echo "   - 默认IP: 192.168.100.254"
echo "   - 防火墙: 老版 iptables"
echo "   - USB挂载: /mnt/usb_disk"
echo "   - 文件共享: ksmbd + vsftpd"
echo "   - 下载服务: Aria2 + AriaNg"
echo "   - 美化主题: kucat"
echo "=========================================="