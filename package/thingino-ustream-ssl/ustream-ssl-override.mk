################################################################################
#
# ustream-ssl overrides for Thingino
#
################################################################################

ifeq ($(BR2_PACKAGE_THINGINO_USTREAM_SSL),y)

# Prefer wolfSSL backend when wolfSSL is selected (and mbedTLS is not).
ifeq ($(BR2_PACKAGE_MBEDTLS),y)
# mbedTLS wins when enabled.
else ifneq ($(BR2_PACKAGE_WOLFSSL)$(BR2_PACKAGE_THINGINO_WOLFSSL),)
# Replace openssl/mbedtls with wolfssl
override USTREAM_SSL_DEPENDENCIES := $(filter-out openssl mbedtls,$(USTREAM_SSL_DEPENDENCIES))
ifeq ($(BR2_PACKAGE_THINGINO_WOLFSSL),y)
override USTREAM_SSL_DEPENDENCIES += thingino-wolfssl
else
override USTREAM_SSL_DEPENDENCIES += wolfssl
endif
override USTREAM_SSL_CONF_OPTS := -DWOLFSSL=ON -DMBEDTLS=OFF
endif

endif # BR2_PACKAGE_THINGINO_USTREAM_SSL
