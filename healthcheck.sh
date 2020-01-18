#!/bin/ash
exit_code=0
exit_code="$(wget --quiet --tries=1 --spider --no-check-certificate "http://${HOSTNAME}:4040/subsonic" && echo ${?})"
if [ "${exit_code}" != 0 ]; then
   echo "HTTP WebUI not responding: Error ${exit_code}"
   exit 1
fi
exit_code="$(wget --quiet --tries=1 --spider --no-check-certificate "https://${HOSTNAME}:4141/subsonic" && echo ${?})"
if [ "${exit_code}" != 0 ]; then
   echo "HTTPS WebUI not responding: Error ${exit_code}"
   exit 1
fi
echo "WebUIs available"
exit 0