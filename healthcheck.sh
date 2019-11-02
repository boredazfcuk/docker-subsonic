#!/bin/ash
wget --quiet --tries=1 --no-check-certificate --spider "http://${HOSTNAME}:4040/subsonic" || exit 1
wget --quiet --tries=1 --no-check-certificate --spider "https://${HOSTNAME}:4141/subsonic" || exit 1
exit 0