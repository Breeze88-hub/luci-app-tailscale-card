module("luci.controller.tailscale", package.seeall)

function index()
	local fs = require "nixio.fs"
	if not fs.access("/etc/config/tailscale") then
		return
	end

	local page = node("admin", "vpn", "tailscale")
	page.target = firstchild()
	page.title  = "Tailscale"
	page.order  = 60

	local d = node("admin", "vpn", "tailscale", "devices")
	d.target = template("tailscale/devices")
	d.title  = "设备"
	d.order  = 5

	local s = node("admin", "vpn", "tailscale", "status")
	s.target = template("tailscale/status")
	s.title  = "概览"
	s.order  = 10

	local c = node("admin", "vpn", "tailscale", "setting")
	c.target = cbi("tailscale/setting")
	c.title  = "设置"
	c.order  = 20

	entry({"admin", "vpn", "tailscale", "action"}, call("action_ts")).leaf = true
	entry({"admin", "vpn", "tailscale", "traffic"}, call("traffic_action")).leaf = true
end

-- 读 tailscale0 计数器
local function counters()
	local rx, tx = 0, 0
	local f = io.open("/sys/class/net/tailscale0/statistics/rx_bytes", "r")
	if f then rx = tonumber(f:read("*l")) or 0; f:close() end
	f = io.open("/sys/class/net/tailscale0/statistics/tx_bytes", "r")
	if f then tx = tonumber(f:read("*l")) or 0; f:close() end
	return rx, tx
end

-- 按小时聚合 7 天流量（来自 /etc/tailscale/traffic.csv）
local function traffic_json()
	local buckets, order = {}, {}
	local total_rx, total_tx, samples = 0, 0, 0
	local prev_rx, prev_tx, prev_t

	local f = io.open("/etc/tailscale/traffic.csv", "r")
	if f then
		for line in f:lines() do
			local t, rx, tx = line:match("^(%d+),(%d+),(%d+)$")
			if t then
				samples = samples + 1
				t, rx, tx = tonumber(t), tonumber(rx), tonumber(tx)
				if prev_rx and rx >= prev_rx and tx >= prev_tx then
					local dt = t - prev_t
					-- 采样中断超过 1 小时就不计增量，避免把重启跨度算成突发
					if dt > 0 and dt <= 3600 then
						local drx, dtx = rx - prev_rx, tx - prev_tx
						local h = math.floor(t / 3600) * 3600
						if not buckets[h] then
							buckets[h] = { rx = 0, tx = 0 }
							order[#order + 1] = h
						end
						buckets[h].rx = buckets[h].rx + drx
						buckets[h].tx = buckets[h].tx + dtx
						total_rx = total_rx + drx
						total_tx = total_tx + dtx
					end
				end
				prev_rx, prev_tx, prev_t = rx, tx, t
			end
		end
		f:close()
	end

	table.sort(order)
	local pts = {}
	for _, h in ipairs(order) do
		pts[#pts + 1] = string.format('{"t":%d,"rx":%d,"tx":%d}', h, buckets[h].rx, buckets[h].tx)
	end

	return string.format(
		'{"ok":true,"total_rx":%d,"total_tx":%d,"samples":%d,"count":%d,"points":[%s]}',
		total_rx, total_tx, samples, #pts, table.concat(pts, ","))
end

function traffic_action()
	luci.http.prepare_content("application/json")
	luci.http.write(traffic_json())
end

function action_ts()
	local act = luci.http.formvalue("do")

	if act == "ping" then
		local ip = (luci.http.formvalue("ip") or ""):gsub("[^%d%.%:]", "")
		luci.http.prepare_content("text/plain")
		if ip == "" then
			luci.http.write("timeout")
			return
		end
		local out = luci.sys.exec("tailscale ping -c 1 --timeout 3s " .. ip .. " 2>&1 | head -3")
		out = (out or ""):gsub("%s+$", "")
		if out == "" or not out:find("pong") then out = "timeout" end
		luci.http.write(out)
		return
	end

	if act == "traffic" then
		luci.http.prepare_content("application/json")
		luci.http.write(traffic_json())
		return
	end

	if act == "restart" then
		luci.sys.call("/etc/init.d/tailscale restart >/tmp/ts_action.log 2>&1")
	elseif act == "stop" then
		luci.sys.call("/etc/init.d/tailscale stop >/tmp/ts_action.log 2>&1")
	elseif act == "start" then
		luci.sys.call("/etc/init.d/tailscale start >/tmp/ts_action.log 2>&1")
	elseif act == "logout" then
		luci.sys.call("tailscale logout >/tmp/ts_action.log 2>&1")
	end

	luci.http.redirect(luci.dispatcher.build_url("admin", "vpn", "tailscale", "status"))
end
