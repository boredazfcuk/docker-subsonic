#!/bin/ash

##### Functions #####
Initialise(){
   SUBSONIC_HOST="$(hostname -i)"
   SUBSONIC_HOME="${app_base_dir:=/Subsonic}"
   SUBSONIC_PORT=4040
   SUBSONIC_HTTPS_PORT=4141
   echo -e "\n"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting application container *****"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Username: ${stack_user:=stackman}:${user_id:=1000}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Password: ${stack_password:=Skibidibbydibyodadubdub}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Group: ${group:=subsonic}:${group_id:=1000}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuration directory: ${config_dir:=/config}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic configuration variables:"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:       SUBSONIC_HOME: ${SUBSONIC_HOME}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:       SUBSONIC_MAX_MEMORY: ${SUBSONIC_MAX_MEMORY:=512}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:       SUBSONIC_CONTEXT_PATH: ${SUBSONIC_CONTEXT_PATH:=/}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:       SUBSONIC_PORT: ${SUBSONIC_PORT:=4040}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:       SUBSONIC_HTTPS_PORT: ${SUBSONIC_HTTPS_PORT:=4141}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:       SUBSONIC_DEFAULT_MUSIC_FOLDER: ${SUBSONIC_DEFAULT_MUSIC_FOLDER:=/storage/music/}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:       SUBSONIC_DEFAULT_PODCAST_FOLDER: ${SUBSONIC_DEFAULT_PODCAST_FOLDER:=/storage/music/Podcast}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:       SUBSONIC_DEFAULT_PLAYLIST_FOLDER: ${SUBSONIC_DEFAULT_PLAYLIST_FOLDER:=/var/playlists/}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic available at: http://${SUBSONIC_HOST}:4040${SUBSONIC_CONTEXT_PATH}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic available at: https://${SUBSONIC_HOST}:4141${SUBSONIC_CONTEXT_PATH}"
   if [ ! -d "${app_base_dir}/transcode/" ]; then mkdir "${app_base_dir}/transcode/"; fi
   if [ -f "/usr/bin/ffmpeg" ] && [ ! -L "${app_base_dir}/transcode/ffmpeg" ]; then ln -s "/usr/bin/ffmpeg" "${app_base_dir}/transcode/"; fi
   if [ -f "/usr/bin/lame" ] && [ ! -L "${app_base_dir}/transcode/lame" ]; then ln -s "/usr/bin/lame" "${app_base_dir}/transcode/"; fi
   if [ ! -d "${config_dir}/db/" ]; then mkdir "${config_dir}/db/"; fi
   if [ ! -L "${app_base_dir}/db/" ]; then ln -s "${config_dir}/db/" "${app_base_dir}/"; fi
   if [ ! -f "${config_dir}/subsonic.properties" ]; then touch "${config_dir}/subsonic.properties"; fi
   if [ ! -L "${app_base_dir}/subsonic.properties" ]; then ln -s "${config_dir}/subsonic.properties" "${app_base_dir}/"; fi
   if [ ! -L "${app_base_dir}/subsonic.log" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Redirect Subsonic log to stdout"
      if [ -f "${app_base_dir}/subsonic.log" ]; then rm "${app_base_dir}/subsonic.log"; fi
      ln -sf "/dev/stdout" "${app_base_dir}/subsonic.log"
   fi
   
}

EnableSSL(){
   if [ ! -d "${config_dir}/https" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Initialise HTTPS"
      mkdir -p "${config_dir}/https"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate server key"
      openssl ecparam -genkey -name secp384r1 -out "${config_dir}/https/subsonic.key"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Create certificate request"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=Subsonic/OU=Subsonic/CN=Subsonic/" -key "${config_dir}/https/subsonic.key" -out "${config_dir}/https/subsonic.csr"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate certificate request"
      openssl x509 -req -sha256 -days 3650 -in "${config_dir}/https/subsonic.csr" -signkey "${config_dir}/https/subsonic.key" -out "${config_dir}/https/subsonic.crt" >/dev/null 2>&1
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Convert to pkcs12 format"
      openssl pkcs12 -export -inkey "${config_dir}/https/subsonic.key" -in "${config_dir}/https/subsonic.crt" -out "${config_dir}/https/subsonic.pkcs12" -password pass:subsonic
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Create pkcs12 keystore"
      keytool -importkeystore -srckeystore "${config_dir}/https/subsonic.pkcs12" -srcstoretype PKCS12 -destkeystore "${app_base_dir}/subsonic.keystore" -deststorepass subsonic -srcstorepass subsonic -noprompt
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Import keystore to Subsonic"
      zip -j "${app_base_dir}/subsonic-booter-jar-with-dependencies.jar" "${app_base_dir}/subsonic.keystore"
   fi
}

CreateGroup(){
   if [ -z "$(getent group "${group}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Group ID available, creating group"
      addgroup -g "${group_id}" "${group}"
   elif [ ! "$(getent group "${group}" | cut -d: -f3)" = "${group_id}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   Group group_id mismatch - exiting"
      exit 1
   fi
}

CreateUser(){
   if [ -z "$(getent passwd "${stack_user}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    User ID available, creating user"
      adduser -s /bin/ash -H -D -G "${group}" -u "${user_id}" "${stack_user}"
   elif [ ! "$(getent passwd "${stack_user}" | cut -d: -f3)" = "${user_id}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   User ID already in use - exiting"
      exit 1
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Correct owner and group of application files, if required"
   find -L "${app_base_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find -L "${app_base_dir}" ! -group "${group}" -exec chgrp "${group}" {} \;
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${group}" -exec chgrp "${group}" {} \;
}

RemoveLockFile(){
   if [ -f "${config_dir}/db/subsonic.lck" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Lock file already exists. Previous shutdown was not clean. Removing lock file"
      rm "${config_dir}/db/subsonic.lck"
   fi

}

LaunchSubsonic(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Configuration of Subsonic container launch environment complete *****"
   if [ -z "${1}" ]; then
       echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting Subsonic as ${stack_user}"
	   export SUBSONIC_HOST SUBSONIC_HOME SUBSONIC_MAX_MEMORY SUBSONIC_CONTEXT_PATH SUBSONIC_DB SUBSONIC_PORT SUBSONIC_HTTPS_PORT SUBSONIC_DEFAULT_MUSIC_FOLDER
	   exec "$(which su)" -p "${stack_user}" -c "${app_base_dir}/subsonic.sh && sleep 999999"
   else
      exec "$@"
   fi
}

##### Script #####
Initialise
EnableSSL
CreateGroup
CreateUser
SetOwnerAndGroup
RemoveLockFile
LaunchSubsonic