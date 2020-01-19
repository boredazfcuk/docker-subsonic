#!/bin/ash

##### Functions #####
Initialise(){
   SUBSONIC_HOST="$(hostname -i)"
   SUBSONIC_HOME="${app_base_dir}"
   SUBSONIC_PORT=4040
   SUBSONIC_HTTPS_PORT=4141
   export SUBSONIC_HOST SUBSONIC_HOME SUBSONIC_MAX_MEMORY subsonic_context_path SUBSONIC_DB SUBSONIC_PORT SUBSONIC_HTTPS_PORT

   echo -e "\n"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting application container *****"
   if [ -z "${stack_user}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User name not set, defaulting to 'stackman'"; stack_user="stackman"; fi
   if [ -z "${stack_password}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Password not set, defaulting to 'Skibidibbydibyodadubdub'"; stack_password="Skibidibbydibyodadubdub"; fi   
   if [ -z "${user_id}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User ID not set, defaulting to '1000'"; user_id="1000"; fi
   if [ -z "${group}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group name not set, defaulting to 'group'"; group="group"; fi
   if [ -z "${group_id}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group ID not set, defaulting to '1000'"; group_id="1000"; fi

   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local user: ${stack_user}:${user_id}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local group: ${group}:${group_id}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic directory: ${SUBSONIC_HOME}"

   if [ -z "${SUBSONIC_MAX_MEMORY}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SUBSONIC_MAX_MEMORY not set, defaulting to 512MB"
      SUBSONIC_MAX_MEMORY="512"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SUBSONIC_MAX_MEMORY set to ${SUBSONIC_MAX_MEMORY}MB"
   fi
   if [ -z "${subsonic_context_path}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    subsonic_context_path not set, defaulting to /"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    subsonic_context_path set to ${subsonic_context_path}"
   fi
   if [ -z "${SUBSONIC_PORT}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SUBSONIC_PORT not set, defaulting to 4040"
      SUBSONIC_PORT=4040
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SUBSONIC_PORT set to ${SUBSONIC_PORT}"
   fi
   if [ -z "${SUBSONIC_HTTPS_PORT}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SUBSONIC_HTTPS_PORT not set, defaulting to 4141"
      SUBSONIC_HTTPS_PORT=4141
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SUBSONIC_HTTPS_PORT set to ${SUBSONIC_HTTPS_PORT}"
   fi

   if [ "${SUBSONIC_DEFAULT_MUSIC_FOLDER}" ]; then 
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic default music directory: ${SUBSONIC_DEFAULT_MUSIC_FOLDER}"
   fi

   if [ "${SUBSONIC_DEFAULT_PODCAST_FOLDER}" ]; then 
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic default music directory: ${SUBSONIC_DEFAULT_PODCAST_FOLDER}"
   fi

   if [ "${SUBSONIC_DEFAULT_PLAYLIST_FOLDER}" ]; then 
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic default music directory: ${SUBSONIC_DEFAULT_PLAYLIST_FOLDER}"
   fi

   if [ ! -f "${config_dir}/https" ]; then
      mkdir -p "${config_dir}/https"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate private key for encrypting communications"
      openssl ecparam -genkey -name secp384r1 -out "${config_dir}/https/subsonic.key"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Create certificate request"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=Subsonic/OU=Subsonic/CN=Subsonic/" -key "${config_dir}/https/subsonic.key" -out "${config_dir}/https/subsonic.csr"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate self-signed certificate request"
      openssl x509 -req -sha256 -days 3650 -in "${config_dir}/https/subsonic.csr" -signkey "${config_dir}/https/subsonic.key" -out "${config_dir}/https/subsonic.crt" >/dev/null 2>&1
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Convert to pkcs12 format"
      openssl pkcs12 -export -inkey "${config_dir}/https/subsonic.key" -in "${config_dir}/https/subsonic.crt" -out "${config_dir}/https/subsonic.pkcs12" -password pass:subsonic
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Create pkcs12 keystore"
      keytool -importkeystore -srckeystore "${config_dir}/https/subsonic.pkcs12" -srcstoretype PKCS12 -destkeystore "${app_base_dir}/subsonic.keystore" -deststorepass subsonic -srcstorepass subsonic -noprompt
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Import keystore to Subsonic"
      zip -j "${app_base_dir}/subsonic-booter-jar-with-dependencies.jar" "${app_base_dir}/subsonic.keystore"
   fi

   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic available at: http://${SUBSONIC_HOST}:4040${subsonic_context_path}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic available at: https://${SUBSONIC_HOST}:4141${subsonic_context_path}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuration directory: ${config_dir}"
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
   if [ ! -f "${app_base_dir}/subsonic_sh.log" ]; then touch "${app_base_dir}/subsonic_sh.log"; fi
   if [ ! -f "${app_base_dir}/subsonic.log" ]; then touch "${app_base_dir}/subsonic.log"; fi
   find -L "${app_base_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find -L "${app_base_dir}" ! -group "${group}" -exec chgrp "${group}" {} \;
   find "${config_dir}" ! -user "${stack_user}" -exec chown "${stack_user}" {} \;
   find "${config_dir}" ! -group "${group}" -exec chgrp "${group}" {} \;
}

LaunchSubsonic(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting Subsonic as ${stack_user}"
   if [ -f "${config_dir}/db/subsonic.lck" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Lock file already exists. Previous shutdown was not clean. Removing lock file"
      rm "${config_dir}/db/subsonic.lck"
   fi
   su -m "${stack_user}" -c "${app_base_dir}"'/subsonic.sh'
   tail -Fn0 "${app_base_dir}/subsonic_sh.log" &
   tail -Fn0 "${app_base_dir}/subsonic.log"
}

##### Script #####
Initialise
CreateGroup
CreateUser
SetOwnerAndGroup
LaunchSubsonic