#!/bin/sh
#
# 一键安装 luci-app-tailscale-card（OpenWrt / Lua LuCI）
#
#   uclient-fetch -O- https://raw.githubusercontent.com/Breeze88-hub/luci-app-tailscale-card/main/install.sh | sh
#
# 幂等：重复执行只会覆盖同一批文件，不会重复装包。
# 卸载见脚本末尾的提示。
#
set -e

REPO="Breeze88-hub/luci-app-tailscale-card"
BRANCH="${BRANCH:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"

PKGS="tailscale luci-compat luci-lib-jsonc"
LUCI_CTL="/usr/lib/lua/luci/controller"
LUCI_VIEW="/usr/lib/lua/luci/view/tailscale"
LUCI_CBI="/usr/lib/lua/luci/model/cbi/tailscale"
CSS_DIR="/www/luci-static/resources/tailscale"
HOTPLUG="/etc/hotplug.d/iface"

say() { printf '%s\n' "$*"; }
die() { printf '错误: %s\n' "$*" >&2; exit 1; }

[ -f /etc/openwrt_release ] || say "警告: 未检测到 /etc/openwrt_release，仍继续。"

# ---------- 下载器 ----------
TMP="/tmp/luci-app-tailscale-card.$$"
fetch() {
	# fetch <url> <dest>
	if command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -q -O "$2" "$1"
	elif command -v curl >/dev/null 2>&1; then
		curl -fsSL "$1" -o "$2"
	elif command -v wget >/dev/null 2>&1; then
		wget -q "$1" -O "$2"
	else
		die "需要 uclient-fetch、curl 或 wget 之一"
	fi
}

# ---------- 依赖 ----------
missing=""
for p in $PKGS; do
	if opkg list-installed 2>/dev/null | grep -q "^$p "; then
		say "· 已装 $p"
	else
		missing="$missing $p"
	fi
done
if [ -n "$missing" ]; then
	say "· 安装依赖:$missing"
	opkg update >/dev/null 2>&1 || say "  警告: opkg update 失败，继续"
	for p in $missing; do
		opkg install "$p" || die "安装 $p 失败（检查网络 / 软件源）"
	done
fi

# ---------- 文件 ----------
get() {
	# get <repo-relative-path> <dest> [chmod]
	src="$1"; dest="$2"; mode="$3"
	mkdir -p "$(dirname "$dest")"
	fetch "$RAW/$src" "$dest" || die "下载 $src 失败"
	[ -n "$mode" ] && chmod "$mode" "$dest" || true
	say "  → $dest"
}

say "· 下载并安装文件（$BRANCH）"
get "luasrc/controller/tailscale.lua"                        "$LUCI_CTL/tailscale.lua"
get "luasrc/view/tailscale/devices.htm"                      "$LUCI_VIEW/devices.htm"
get "luasrc/view/tailscale/status.htm"                       "$LUCI_VIEW/status.htm"
get "luasrc/model/cbi/tailscale/setting.lua"                 "$LUCI_CBI/setting.lua"
get "htdocs/luci-static/resources/tailscale/ui.css"          "$CSS_DIR/ui.css"
get "root/usr/bin/tailscale-traffic-sampler"                 "/usr/bin/tailscale-traffic-sampler"       755
get "root/etc/hotplug.d/iface/95-lan-ipv6-ra"                "$HOTPLUG/95-lan-ipv6-ra"                  755

# ---------- 收尾 ----------
say "· 清理 LuCI 缓存"
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null || true

if [ -x /etc/init.d/uhttpd ]; then
	/etc/init.d/uhttpd restart >/dev/null 2>&1 || say "  警告: uhttpd 重启失败，请手动重启"
fi

say ""
say "完成。入口: VPN → Tailscale  (/cgi-bin/luci/admin/vpn/tailscale/devices)"
say ""
say "还没做的两件事（按需）："
say "  1) 流量图需要 cron:  echo '*/5 * * * * /usr/bin/tailscale-traffic-sampler' >> /etc/crontabs/root"
say "  2) 透明代理环境下 Tailscale 打不成 P2P: 参考 README 的「让 P2P 直连生效」"
say ""
say "卸载: rm -f $LUCI_CTL/tailscale.lua $LUCI_VIEW/*.htm $LUCI_CBI/setting.lua \\"
say "        $CSS_DIR/ui.css /usr/bin/tailscale-traffic-sampler $HOTPLUG/95-lan-ipv6-ra"