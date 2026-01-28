################################################################################
#
# thingino-ustream-ssl - virtual package that selects custom ustream-ssl build
#
################################################################################

# The actual ustream-ssl overrides live in ustream-ssl-override.mk.
THINGINO_USTREAM_SSL_DEPENDENCIES = ustream-ssl

$(eval $(virtual-package))
