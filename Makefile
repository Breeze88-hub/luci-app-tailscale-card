#
# Copyright (C) 2026 luci-app-tailscale-card
#
# This is free software, licensed under the MIT License.
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI app for Tailscale (card-style UI)
LUCI_DESCRIPTION:=Card-style Tailscale management UI for Lua LuCI: device list with ping, \
	overview with 7-day traffic chart, settings, light/dark themes.
LUCI_DEPENDS:=+tailscale +luci-compat +luci-lib-jsonc
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-tailscale-card
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Breeze88-hub <Breeze88-hub@users.noreply.github.com>

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
