#!/bin/ash

if [ "$(netstat -plnt | grep -c 4040)" -ne 1 ]; then
   echo "Subsonic HTTP port 4040 is not responding"
   exit 1
fi

if [ "$(netstat -plnt | grep -c 4141)" -ne 1 ]; then
   echo "Subsonic HTTP port 4141 is not responding"
   exit 1
fi

echo "Subsonic ports 4040 and 4141 responding OK"
exit 0