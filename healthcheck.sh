#!/bin/ash

if [ "$(nc -z "$(hostname -i)" 4040; echo $?)" -ne 0 ]; then
   echo "Subsonic HTTP port 4040 is not responding"
   exit 1
fi

if [ "$(nc -z "$(hostname -i)" 4141; echo $?)" -ne 0 ]; then
   echo "Subsonic HTTP port 4141 is not responding"
   exit 1
fi

echo "Subsonic ports 4040 and 4141 responding OK"
exit 0