local m, s, o

m = Map("tailscale", "Tailscale 设置",
	"修改后点击「保存并应用」；启用/主机名/子网路由等参数需到「运行状态」页点一次「重启服务」才生效。")

s = m:section(NamedSection, "settings", "tailscale", "基本")
s.addremove = false
s.anonymous = true

o = s:option(Flag, "enabled", "启用 Tailscale")
o.rmempty = false
o.default = "0"

o = s:option(Value, "hostname", "主机名",
	"留空则使用系统名；在 tailnet 管理台里显示的名字")
o.placeholder = "bleachwrt-router"

o = s:option(Value, "port", "监听端口")
o.datatype = "port"
o.default = "41641"
o.placeholder = "41641"

o = s:option(ListValue, "fw_mode", "防火墙模式",
	"本固件是 fw3/iptables，必须选 iptables；nftables 会导致规则不生效")
o:value("iptables", "iptables（本固件使用）")
o:value("nftables", "nftables")
o.default = "iptables"

o = s:option(ListValue, "accept_dns", "接受 MagicDNS",
	"选「否」可避免 tailscale 接管 DNS，防止覆盖 dnsmasq + ChinaDNS + passwall 的分流")
o:value("0", "否（推荐：不影响现有分流）")
o:value("1", "是（接管 DNS）")
o.default = "0"

o = s:option(Value, "config_path", "状态目录",
	"tailscaled.state 所在目录，持久化后方可重启不掉登录")
o.default = "/etc/tailscale"

s2 = m:section(NamedSection, "settings", "tailscale", "子网路由 / Exit Node")
s2.addremove = false
s2.anonymous = true

o = s2:option(DynamicList, "advertise_routes", "对外宣告的子网",
	"把本站局域网暴露给整个 tailnet，例如 192.168.1.0/24；宣告后需在管理台批准")
o.placeholder = "192.168.1.0/24"

o = s2:option(DynamicList, "subnet_routes", "接入其他站点的子网",
	"站点到站点（site-to-site）时填写对方子网")

o = s2:option(Flag, "advertise_exit_node", "作为 Exit Node",
	"让 tailnet 内设备通过本机出网（需在管理台批准）")
o.default = "0"

o = s2:option(Value, "exit_node", "使用 Exit Node",
	"填写对端 Tailscale IP 或主机名；留空表示不使用")

o = s2:option(Flag, "disable_snat_subnet_routes", "禁用子网路由 SNAT")
o.default = "0"

s3 = m:section(NamedSection, "settings", "tailscale", "防火墙互访")
s3.addremove = false
s3.anonymous = true

o = s3:option(DynamicList, "access", "访问权限",
	"登录成功后会按这些勾选自动创建 tailscale 防火墙区域与转发规则")
o:value("ts_ac_lan", "Tailscale → LAN（tailnet 访问内网，子网路由必须）")
o:value("ts_ac_wan", "Tailscale → WAN")
o:value("lan_ac_ts", "LAN → Tailscale（内网设备访问 tailnet 地址）")
o:value("wan_ac_ts", "WAN → Tailscale")

s4 = m:section(NamedSection, "settings", "tailscale", "高级")
s4.addremove = false
s4.anonymous = true

o = s4:option(Value, "login_server", "自定义控制服务器",
	"自建 headscale 时填写，例如 https://headscale.example.com")
o.placeholder = "https://controlplane.tailscale.com"

o = s4:option(Value, "authkey", "预授权 Auth Key",
	"填写后可免浏览器登录自动上线（tskey-auth-...）")
o.password = true

o = s4:option(Value, "flags", "额外 up 参数",
	"会原样附加到 tailscale up 命令后，例如 --ssh --advertise-tags=tag:router")
o.placeholder = "--ssh"

return m
