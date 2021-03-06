#!/bin/ash

##### Functions #####
Initialise(){
   default_gateway="$(ip route | grep "^default" | awk '{print $3}')"
   SUBSONIC_HOST="$(hostname -i)"
   SUBSONIC_HOME="${app_base_dir:=/Subsonic}"
   SUBSONIC_CONTEXT_PATH="${subsonic_context_path}"
   SUBSONIC_PORT=3030
   SUBSONIC_HTTPS_PORT=3131
   echo
   echo "$(date '+%c') INFO:    ***** Starting application container *****"
   echo "$(date '+%c') INFO:    $(cat /etc/*-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/"//g')"
   echo "$(date '+%c') INFO:    Username: ${stack_user:=stackman}:${stack_uid:=1000}"
   echo "$(date '+%c') INFO:    Password: ${stack_password:=Skibidibbydibyodadubdub}"
   echo "$(date '+%c') INFO:    Group: ${group:=subsonic}:${group_id:=1000}"
   echo "$(date '+%c') INFO:    Configuration directory: ${config_dir:=/config}"
   echo "$(date '+%c') INFO:    Subsonic configuration variables:"
   echo "$(date '+%c') INFO:       SUBSONIC_HOME: ${SUBSONIC_HOME}"
   echo "$(date '+%c') INFO:       SUBSONIC_MAX_MEMORY: ${SUBSONIC_MAX_MEMORY:=512}"
   echo "$(date '+%c') INFO:       SUBSONIC_CONTEXT_PATH: ${SUBSONIC_CONTEXT_PATH:=/}"
   echo "$(date '+%c') INFO:       SUBSONIC_PORT: ${SUBSONIC_PORT:=4040}"
   echo "$(date '+%c') INFO:       SUBSONIC_HTTPS_PORT: ${SUBSONIC_HTTPS_PORT:=4141}"
   echo "$(date '+%c') INFO:       SUBSONIC_DEFAULT_MUSIC_FOLDER: ${SUBSONIC_DEFAULT_MUSIC_FOLDER:=/storage/music/}"
   echo "$(date '+%c') INFO:       SUBSONIC_DEFAULT_PODCAST_FOLDER: ${SUBSONIC_DEFAULT_PODCAST_FOLDER:=/storage/music/Podcast}"
   echo "$(date '+%c') INFO:       SUBSONIC_DEFAULT_PLAYLIST_FOLDER: ${SUBSONIC_DEFAULT_PLAYLIST_FOLDER:=/var/playlists/}"
   echo "$(date '+%c') INFO:    Subsonic available at: http://${SUBSONIC_HOST}:3030${SUBSONIC_CONTEXT_PATH}"
   echo "$(date '+%c') INFO:    Subsonic available at: https://${SUBSONIC_HOST}:3131${SUBSONIC_CONTEXT_PATH}"
   echo "$(date '+%c') INFO:    Docker host LAN IP subnet: ${host_lan_ip_subnet}"
   if [ ! -d "${app_base_dir}/transcode/" ]; then mkdir "${app_base_dir}/transcode/"; fi
   if [ -f "/usr/bin/ffmpeg" ] && [ ! -L "${app_base_dir}/transcode/ffmpeg" ]; then ln -s "/usr/bin/ffmpeg" "${app_base_dir}/transcode/"; fi
   if [ -f "/usr/bin/lame" ] && [ ! -L "${app_base_dir}/transcode/lame" ]; then ln -s "/usr/bin/lame" "${app_base_dir}/transcode/"; fi
   if [ ! -d "${config_dir}/db/" ]; then mkdir "${config_dir}/db/"; fi
   if [ ! -L "${app_base_dir}/db/" ]; then 
      if [ -d "${app_base_dir}/db/" ]; then rm -r "${app_base_dir}/db/"; fi
      ln -s "${config_dir}/db/" "${app_base_dir}"
   fi
   if [ ! -f "${config_dir}/subsonic.properties" ]; then touch "${config_dir}/subsonic.properties"; fi
   if [ ! -L "${app_base_dir}/subsonic.properties" ]; then ln -s "${config_dir}/subsonic.properties" "${app_base_dir}/"; fi
   if [ ! -L "${app_base_dir}/subsonic.log" ]; then
      echo "$(date '+%c') INFO:    Redirect Subsonic log to stdout"
      if [ -f "${app_base_dir}/subsonic.log" ]; then rm "${app_base_dir}/subsonic.log"; fi
      ln -sf "/dev/stdout" "${app_base_dir}/subsonic.log"
   fi
}

CheckPIANextGen(){
   if [ "${pianextgen_enabled}" ]; then
      echo "$(date '+%c') INFO:    PIANextGen is enabled. Wait for VPN to connect"
      vpn_adapter="$(ip addr | grep tun.$ | awk '{print $7}')"
      while [ -z "${vpn_adapter}" ]; do
         vpn_adapter="$(ip addr | grep tun.$ | awk '{print $7}')"
         sleep 5
      done
      echo "$(date '+%c') INFO:    VPN adapter available: ${vpn_adapter}"
   else
      echo "$(date '+%c') INFO:    PIANextGen shared network stack is not enabled, configure container forwarding mode mode"
      pianextgen_host="$(getent hosts pianextgen | awk '{print $1}')"
      echo "$(date '+%c') INFO:    PIANextGen container IP address: ${pianextgen_host}"
      echo "$(date '+%c') INFO:    Create default route via ${pianextgen_host}"
      ip route del default 
      ip route add default via "${pianextgen_host}"
      echo "$(date '+%c') INFO:    Create additional route to Docker host network ${host_lan_ip_subnet} via ${default_gateway}"
      ip route add "${host_lan_ip_subnet}" via "${default_gateway}"
   fi
}

EnableSSL(){
   if [ ! -d "${config_dir}/https" ]; then
      echo "$(date '+%c') INFO:    Initialise HTTPS"
      mkdir -p "${config_dir}/https"
      echo "$(date '+%c') INFO:    Generate server key"
      openssl ecparam -genkey -name secp384r1 -out "${config_dir}/https/subsonic.key"
      echo "$(date '+%c') INFO:    Create certificate request"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=Subsonic/OU=Subsonic/CN=Subsonic/" -key "${config_dir}/https/subsonic.key" -out "${config_dir}/https/subsonic.csr"
      echo "$(date '+%c') INFO:    Generate certificate request"
      openssl x509 -req -sha256 -days 3650 -in "${config_dir}/https/subsonic.csr" -signkey "${config_dir}/https/subsonic.key" -out "${config_dir}/https/subsonic.crt" >/dev/null 2>&1
      echo "$(date '+%c') INFO:    Convert to pkcs12 format"
      openssl pkcs12 -export -inkey "${config_dir}/https/subsonic.key" -in "${config_dir}/https/subsonic.crt" -out "${config_dir}/https/subsonic.pkcs12" -password pass:subsonic
      echo "$(date '+%c') INFO:    Create pkcs12 keystore"
      keytool -importkeystore -srckeystore "${config_dir}/https/subsonic.pkcs12" -srcstoretype PKCS12 -destkeystore "${app_base_dir}/subsonic.keystore" -deststorepass subsonic -srcstorepass subsonic -noprompt
      echo "$(date '+%c') INFO:    Import keystore to Subsonic"
      zip -j "${app_base_dir}/subsonic-booter-jar-with-dependencies.jar" "${app_base_dir}/subsonic.keystore"
   fi
}

CreateGroup(){
   if [ "$(grep -c "^${group}:x:${group_id}:" "/etc/group")" -eq 1 ]; then
      echo "$(date '+%c') INFO     Group, ${group}:${group_id}, already created"
   else
      if [ "$(grep -c "^${group}:" "/etc/group")" -eq 1 ]; then
         echo "$(date '+%c') ERROR    Group name, ${group}, already in use - exiting"
         sleep 120
         exit 1
      elif [ "$(grep -c ":x:${group_id}:" "/etc/group")" -eq 1 ]; then
         if [ "${force_gid}" = "True" ]; then
            group="$(grep ":x:${group_id}:" /etc/group | awk -F: '{print $1}')"
            echo "$(date '+%c') WARNING  Group id, ${group_id}, already exists - continuing as force_gid variable has been set. Group name to use: ${group}"
         else
            echo "$(date '+%c') ERROR    Group id, ${group_id}, already in use - exiting"
            sleep 120
            exit 1
         fi
      else
         echo "$(date '+%c') INFO     Creating group ${group}:${group_id}"
         addgroup -g "${group_id}" "${group}"
      fi
   fi
}

CreateUser(){
   if [ "$(grep -c "^${stack_user}:x:${stack_uid}:${group_id}" "/etc/passwd")" -eq 1 ]; then
      echo "$(date '+%c') INFO     User, ${stack_user}:${stack_uid}, already created"
   else
      if [ "$(grep -c "^${stack_user}:" "/etc/passwd")" -eq 1 ]; then
         echo "$(date '+%c') ERROR    User name, ${stack_user}, already in use - exiting"
         sleep 120
         exit 1
      elif [ "$(grep -c ":x:${stack_uid}:$" "/etc/passwd")" -eq 1 ]; then
         echo "$(date '+%c') ERROR    User id, ${stack_uid}, already in use - exiting"
         sleep 120
         exit 1
      else
         echo "$(date '+%c') INFO     Creating user ${stack_user}:${stack_uid}"
         adduser -s /bin/ash -D -G "${group}" -u "${stack_uid}" "${stack_user}" -h "/home/${stack_user}"
      fi
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%c') INFO:    Correct owner and group of application files, if required"
   find -L "${app_base_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find -L "${app_base_dir}" ! -group "${group}" -exec chgrp "${group}" {} \;
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${group}" -exec chgrp "${group}" {} \;
}

RemoveLockFile(){
   if [ -f "${config_dir}/db/subsonic.lck" ]; then
      echo "$(date '+%c') WARNING: Lock file already exists. Previous shutdown was not clean. Removing lock file"
      rm "${config_dir}/db/subsonic.lck"
   fi

}

LaunchSubsonic(){
   echo "$(date '+%c') INFO:    ***** Configuration of Subsonic container launch environment complete *****"
   if [ -z "${1}" ]; then
       echo "$(date '+%c') INFO:    Starting Subsonic as ${stack_user}"
# SUBSONIC_HTTPS_PORT
	   export SUBSONIC_HOST SUBSONIC_HOME SUBSONIC_MAX_MEMORY SUBSONIC_CONTEXT_PATH SUBSONIC_DB SUBSONIC_PORT SUBSONIC_DEFAULT_MUSIC_FOLDER
	   exec "$(which su)" -p "${stack_user}" -c "${app_base_dir}/subsonic.sh && sleep 999999"
   else
      exec "$@"
   fi
}

##### Script #####
Initialise
CheckPIANextGen
EnableSSL
CreateGroup
CreateUser
SetOwnerAndGroup
RemoveLockFile
LaunchSubsonic