################################################################################
#
# thingino-libubox - virtual package that selects custom libubox build
#
################################################################################

# The actual libubox overrides live in libubox-override.mk.
THINGINO_LIBUBOX_DEPENDENCIES = libubox

$(eval $(virtual-package))
