#!/bin/ash
EXIT_CODE=0
EXIT_CODE="$(wget --quiet --tries=1 --spider --no-check-certificate "http://${HOSTNAME}:4040/subsonic" && echo ${?})"
if [ "${EXIT_CODE}" != 0 ]; then
   echo "HTTP WebUI not responding: Error ${EXIT_CODE}"
   exit 1
fi
EXIT_CODE="$(wget --quiet --tries=1 --spider --no-check-certificate "https://${HOSTNAME}:4141/subsonic" && echo ${?})"
if [ "${EXIT_CODE}" != 0 ]; then
   echo "HTTPS WebUI not responding: Error ${EXIT_CODE}"
   exit 1
fi
echo "WebUIs available"
exit 0