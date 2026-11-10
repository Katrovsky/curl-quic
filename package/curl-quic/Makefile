include $(TOPDIR)/rules.mk

PKG_NAME:=curl-quic
PKG_VERSION:=8.23.0
PKG_RELEASE:=1

PKG_SOURCE:=curl-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=https://curl.se/download/
PKG_HASH:=8dadd7d2536a314f982ad05a651b713f426bf7d02cc2c76cffb9796f2218e6c5

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=COPYING
PKG_MAINTAINER:=OpenWrt Community

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

# Auxiliary sources for QUIC stack
define Download/nghttp3
  FILE:=nghttp3-1.8.0.tar.xz
  URL:=https://github.com/ngtcp2/nghttp3/releases/download/v1.8.0/
  HASH:=a9dd28970977e6802a3eaf2cfaeae6d0fae60c8d2c0f2c4ce600036a7998ee9a
endef
$(eval $(call Download,nghttp3))

define Download/ngtcp2
  FILE:=ngtcp2-1.11.0.tar.xz
  URL:=https://github.com/ngtcp2/ngtcp2/releases/download/v1.11.0/
  HASH:=382c15bf66b630f26021631b25b7eb1feac42c67c1d6826189d61091dfaa4d09
endef
$(eval $(call Download,ngtcp2))

define Download/quictls
  FILE:=openssl-3.1.5-quic1.tar.gz
  URL:=https://github.com/quictls/openssl/archive/refs/tags/
  HASH:=928a0c484fca5a5b9ae484e7b14e6691e946220d77d86ac4031cbb408655b644
endef
$(eval $(call Download,quictls))

define Package/curl-quic
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=File Transfer
  TITLE:=cURL with HTTP/3 (QUIC) support
  URL:=https://curl.se/
  DEPENDS:=+ca-bundle
  PROVIDES:=curl
endef

define Package/curl-quic/description
  cURL command line tool compiled with full HTTP/3 (QUIC) support
  using static ngtcp2, nghttp3 and QuicTLS.
  Completely independent of host OpenSSL/mbedTLS versions.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./build-bundle.sh $(PKG_BUILD_DIR)/
	chmod +x $(PKG_BUILD_DIR)/build-bundle.sh
endef

define Build/Compile
	DESTDIR="$(PKG_INSTALL_DIR)" \
	PREFIX="/usr" \
	BUILD_DIR="$(PKG_BUILD_DIR)" \
	DL_DIR="$(DL_DIR)" \
	STAGING_DIR="$(STAGING_DIR)" \
	CC="$(TARGET_CC)" \
	CXX="$(TARGET_CXX)" \
	AR="$(TARGET_AR)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_CROSS)strip" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	HOST="$(GNU_TARGET_NAME)" \
	bash $(PKG_BUILD_DIR)/build-bundle.sh
endef

define Package/curl-quic/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/curl $(1)/usr/bin/curl-quic
	$(LN) curl-quic $(1)/usr/bin/curl
endef

$(eval $(call BuildPackage,curl-quic))
