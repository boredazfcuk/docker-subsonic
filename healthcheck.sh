#!/bin/ash
wget -q --spider "http://${HOSTNAME}:4040/subsonic" || exit 1
wget -q --spider "https://${HOSTNAME}:4141/subsonic" || exit 1
exit 0