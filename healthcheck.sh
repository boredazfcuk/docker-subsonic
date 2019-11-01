#!/bin/ash
wget -q --spider --no-check-certificate "http://${HOSTNAME}:4040/subsonic" || exit 1
wget -q --spider --no-check-certificate "https://${HOSTNAME}:4141/subsonic" || exit 1
exit 0