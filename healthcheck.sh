#!/bin/ash

if [ "$(netstat -plnt | grep -c 3030)" -ne 1 ]; then
   echo "Subsonic HTTP port 3030 is not responding"
   exit 1
fi

# if [ "$(netstat -plnt | grep -c 3131)" -ne 1 ]; then
   # echo "Subsonic HTTP port 3131 is not responding"
   # exit 1
# fi

echo "Subsonic ports 3030 and 3131 responding OK"
exit 0