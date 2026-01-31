高通骁龙410云编译immortalwrt

固件主要添加超多 无线网卡驱动为目的!

目前开启usb网络共享驱动

kmod-usb-net-cdc-ether

kmod-usb-net-cdc-mbim

kmod-usb-net-cdc-ncm

kmod-usb-net-huawei-cdc-ncm

kmod-usb-net-ipheth

kmod-usb-net-rndis

目前开启的Realtek系列网卡

kmod-rtw88-8812a

kmod-rtw88-8812au

kmod-rtw88-8814a

kmod-rtw88-8814au

kmod-rtw88-8821a

kmod-rtw88-8821au

kmod-rtw88-8821c

kmod-rtw88-8821cu和rtl8812cu通用

kmod-rtw88-8822b

kmod-rtw88-8822bu

kmod-rtw88-8822c

kmod-rtw88-8822cs

kmod-rtw88-8822cu和rtl8812cu通用



需要其他插件自行通过config_small配置添加，注意同时开启对应依赖选项


![RTL8812CU网卡](https://qqbot.ugcimg.cn/1106413613/28efddef1be940bee43f05f27758994db2be56c8/916b254e6bf0605a98dadfce2eb6e89b)

![8812CU接线焊接图](https://raw.githubusercontent.com/xuxin1955/Actions-OpenWrt/main/pics/IMG_20260131_183658.jpg)


8812CU和8811CU都能完美驱动


![RTL8811CU网卡](https://raw.githubusercontent.com/xuxin1955/Actions-OpenWrt/main/pics/mmexport1769855276375.jpg)

![410插8811CU网卡](https://raw.githubusercontent.com/xuxin1955/Actions-OpenWrt/main/pics/GIF_20260131_184804.gif)
## Credits

- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [Mikubill/transfer](https://github.com/Mikubill/transfer)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Mattraks/delete-workflow-runs](https://github.com/Mattraks/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

## License

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © [**P3TERX**](https://p3terx.com)
