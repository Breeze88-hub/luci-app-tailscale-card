# luci-app-tailscale-card

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-21.02%20%7C%2022.03%20%7C%2023.05%20%7C%2024.10-00A7E1)](https://openwrt.org)
[![LuCI](https://img.shields.io/badge/LuCI-Lua%20%C2%B7%20luci--compat-brightgreen)](https://github.com/openwrt/luci)
[![Lua lint](https://github.com/Breeze88-hub/luci-app-tailscale-card/actions/workflows/lint.yml/badge.svg)](https://github.com/Breeze88-hub/luci-app-tailscale-card/actions/workflows/lint.yml)

**给 Lua LuCI 的 Tailscale 卡片式管理界面** —— 设备在线状态一目了然、逐台 ping 实测延迟、7 天流量曲线、亮色/暗色双主题。

| 设备列表（亮色） | 概览（暗色） |
|---|---|
| ![设备列表](docs/devices-light.png) | ![概览](docs/status-dark.png) |

> 更多截图见 [`docs/`](docs)：`devices-dark.png`、`status-light.png`。

## 为什么还要一个

官方 `tailscale` 包只带命令行；社区常见的 `luci-app-tailscale` 是给新版 ucode/JS LuCI 写的（只有 `htdocs/.../view/*.js` + `menu.d`），在 Lua LuCI 上直接 404。

本项目用 `controller.lua` + `view/*.htm` + 一份独立 CSS 实现同等功能，并额外做了：

- **卡片式设备列表** —— 在线/离线/本机/DERP 徽章，等宽字体 IP 一键复制，逐台 `ping` 实测延迟
- **概览页** —— 连接状态、本机 IP、子网路由、直连/中继统计、7 天流量曲线、服务启停
- **每台设备的「⋯」菜单** —— 复制 SSH 命令、打开/复制 MagicDNS 名、复制 IP
- **亮色 / 暗色双配色**
- **可选**：IPv6 自动获取（让旁路由通过 SLAAC 拿到上游公网 IPv6，Tailscale 才能走 IPv6 P2P）

## 依赖

```
tailscale          # 必需，提供 tailscaled / tailscale
luci-compat        # Lua LuCI 兼容层
luci-lib-jsonc     # 解析 tailscale status --json
```

## 安装

### 方式零：一键脚本（在路由器上执行）

```sh
uclient-fetch -O- https://raw.githubusercontent.com/Breeze88-hub/luci-app-tailscale-card/main/install.sh | sh
```

脚本会先把缺的依赖装上，再把文件铺到对应目录并重启 `uhttpd`。它是幂等的，重复跑不会重复装包。

### 方式一：手动拷贝

```sh
# 在 OpenWrt 上
opkg update
opkg install tailscale luci-compat luci-lib-jsonc

# 把本仓库文件放到对应位置
cp luasrc/controller/tailscale.lua            /usr/lib/lua/luci/controller/
mkdir -p /usr/lib/lua/luci/view/tailscale /usr/lib/lua/luci/model/cbi/tailscale
cp luasrc/view/tailscale/*.htm                /usr/lib/lua/luci/view/tailscale/
cp luasrc/model/cbi/tailscale/setting.lua     /usr/lib/lua/luci/model/cbi/tailscale/
mkdir -p /www/luci-static/resources/tailscale
cp htdocs/luci-static/resources/tailscale/ui.css /www/luci-static/resources/tailscale/
cp root/usr/bin/tailscale-traffic-sampler     /usr/bin/ && chmod +x /usr/bin/tailscale-traffic-sampler
cp root/etc/hotplug.d/iface/95-lan-ipv6-ra    /etc/hotplug.d/iface/ && chmod +x /etc/hotplug.d/iface/95-lan-ipv6-ra

rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache
/etc/init.d/uhttpd restart
```

入口：**VPN → Tailscale**（`/cgi-bin/luci/admin/vpn/tailscale/devices`）。

### 方式二：作为 OpenWrt 包编译

```sh
# 放进 openwrt feeds 或 package 目录
cp -r luci-app-tailscale-card $OPENWRT/package/luci-app-tailscale-card
make menuconfig     # LuCI → Applications → luci-app-tailscale-card
make package/luci-app-tailscale-card/compile V=s
```

### 方式三：直接加 feed

```sh
echo "src-git tailscalecard https://github.com/Breeze88-hub/luci-app-tailscale-card.git" >> feeds.conf.default
./scripts/feeds update tailscalecard
./scripts/feeds install -a -p tailscalecard
```

## 首次配置

```sh
uci set tailscale.settings.enabled='1'
uci set tailscale.settings.hostname='my-router'
uci set tailscale.settings.fw_mode='iptables'    # fw3 固件必须；fw4 用 nftables
uci set tailscale.settings.accept_dns='0'        # 不接管 DNS，避免和 dnsmasq/分流冲突
uci add_list tailscale.settings.advertise_routes='192.168.1.0/24'
uci add_list tailscale.settings.access='ts_ac_lan'
uci add_list tailscale.settings.access='lan_ac_ts'
uci commit tailscale
/etc/init.d/tailscale restart
```

然后到「概览」页点登录链接完成授权，并在 Tailscale 管理台批准子网路由。

## 7 天流量图

`tailscale-traffic-sampler` 每 5 分钟读一次 `tailscale0` 的累计字节数，写入 `/etc/tailscale/traffic.csv`（保留 7 天）。装好后加一条 cron：

```sh
echo '*/5 * * * * /usr/bin/tailscale-traffic-sampler' >> /etc/crontabs/root
/etc/init.d/cron enable && /etc/init.d/cron restart
```

「概览」页的曲线由 `/admin/vpn/tailscale/traffic` 路由按小时聚合返回（需登录）。

## 让 P2P 直连生效（重要）

如果路由器上跑着透明代理（passwall / shellcrash / 其他依赖 iptables TPROXY 的方案），**UDP 41641 会被劫持进代理进程导致打洞失败**，表现为所有节点都是 `relay "xxx"`。加进 `/etc/firewall.user`：

```sh
iptables -t mangle -I OUTPUT 1 -p udp --dport 41641 -j RETURN
iptables -t mangle -I OUTPUT 1 -p udp --sport 41641 -j RETURN
iptables -t mangle -I PREROUTING 1 -p udp --dport 41641 -j RETURN
iptables -t nat    -I PREROUTING 1 -p udp --dport 41641 -j RETURN
```

同时让 `tailscale0` 的入站绕过代理链：

```sh
iptables -t nat    -I PREROUTING 1 -i tailscale0 -j RETURN
iptables -t mangle -I PREROUTING 1 -i tailscale0 -j RETURN
iptables -t nat    -I PREROUTING 1 -d 100.64.0.0/10 -j RETURN
iptables -t mangle -I PREROUTING 1 -d 100.64.0.0/10 -j RETURN
```

验证：`tailscale status` 里出现 `direct 1.2.3.4:41641` 或 `direct [240e:...]:41641` 才算直连；`tailscale ping <peer>` 会打印实际路径。

## IPv6 直连（可选）

单臂旁路由默认拿不到上游 IPv6（`ip6assign` 会让 netifd 把 `accept_ra` 压成 0）。`95-lan-ipv6-ra` 只是兜底，还需要：

```sh
uci delete network.lan.ip6assign && uci commit network
cat >> /etc/sysctl.conf <<'EOF'
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.default.accept_ra=2
EOF
sysctl -p
ifup lan
```

拿到 `inet6 2408:.../64 scope global dynamic` 和 `default via fe80::x proto ra` 后，`tailscale netcheck` 的 `IPv6:` 会变成 `yes`，手机等 IPv6 设备即可走 IPv6 P2P。

## 兼容性

| 项目 | 状态 |
|---|---|
| LuCI | **Lua 版**（`/usr/bin/lua` 驱动的 `/www/cgi-bin/luci`）；ucode/JS LuCI 不适用，请用 client-side view 实现 |
| OpenWrt | 21.02 / 22.03 / 23.05 / 24.10，需 `luci-compat` |
| 防火墙 | fw3（iptables）已实测；fw4（nftables）请把 `fw_mode` 设为 `nftables` |
| 主题 | argon 1.8.4 为准，bootstrap / material 布局正常、配色跟随各自变量 |

页面隐藏了主题自带的二级 tab（与底部 tab 重复），并用 `#maincontent{padding-top:74px}` 给固定 header 让位；如果你的主题 header 高度不同，改这两个值即可。

## 排错

| 现象 | 原因 / 处理 |
|---|---|
| 菜单里没有 Tailscale | `luci-compat` 没装，或 `luci-indexcache` 未清 —— 删 `/tmp/luci-*cache*` 后重启 `uhttpd` |
| 页面 404 但菜单在 | 文件放错目录。`controller.lua` 必须在 `/usr/lib/lua/luci/controller/`，视图在 `/usr/lib/lua/luci/view/tailscale/` |
| 设备全部显示 `relay` | 见上面「让 P2P 直连生效」，UDP 41641 被代理劫持 |
| 流量图空白 | `tailscale-traffic-sampler` 没加 cron，或不到 5 分钟还没采样点 |
| 本机 IP 显示 `100.x` 但点复制无反应 | 非 HTTPS 环境下 `navigator.clipboard` 不可用，页面已回退到 `textarea` 方案；若仍失败请检查浏览器策略 |

## 文件

```
luasrc/controller/tailscale.lua                菜单注册 + ping/traffic 接口 + 服务动作
luasrc/view/tailscale/devices.htm              设备列表（卡片）
luasrc/view/tailscale/status.htm               概览（统计 + 流量图 + 服务操作）
luasrc/model/cbi/tailscale/setting.lua         设置表单
htdocs/luci-static/resources/tailscale/ui.css  全部样式（含暗色）
root/usr/bin/tailscale-traffic-sampler         流量采样
root/etc/hotplug.d/iface/95-lan-ipv6-ra        IPv6 accept_ra 兜底
install.sh                                     一键安装
```

## 更新日志

见 [CHANGELOG.md](CHANGELOG.md)。

## License

[MIT](LICENSE)