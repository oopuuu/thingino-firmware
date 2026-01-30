################################################################################
#
# libubox overrides for Thingino
#
################################################################################

# Force json-c as a dependency to ensure blobmsg_json and json_script are built
LIBUBOX_DEPENDENCIES += json-c
