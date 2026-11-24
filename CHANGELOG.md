# 更新日志

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.0] — 2026-11-24

首个可发布版本。

### 新增

- **设备列表**（`devices` 页）：卡片式布局，在线 / 离线 / 本机 / DERP 徽章，等宽字体 IP 一键复制，逐台 `ping` 实测延迟，每台设备的「⋯」菜单（复制 SSH 命令、打开 / 复制 MagicDNS 名、复制 IP）。
- **概览**（`status` 页）：连接状态、本机 Tailscale IP、子网路由、直连 / 中继统计、7 天流量曲线、服务启停。
- **设置**（CBI 表单）：`enabled` / `hostname` / `fw_mode` / `accept_dns` / `advertise_routes` / `access` 等常用项。
- **亮色 / 暗色双配色**，跟随主题变量。
- `tailscale-traffic-sampler`：每 5 分钟采样 `tailscale0` 累计字节，保留 7 天 CSV。
- `95-lan-ipv6-ra`：单臂旁路由的 `accept_ra` 兜底，配合 `ip6assign` 清理即可拿到上游公网 IPv6。
- `install.sh`：一键安装，幂等。

### 已知限制

- 只支持 **Lua LuCI**（依赖 `luci-compat`），ucode/JS LuCI 不适用。
- fw4（nftables）固件需把 `fw_mode` 设为 `nftables`；本项目实测环境为 fw3。
