#!/bin/ash

##### Functions #####
Initialise(){
   SUBSONIC_HOST="$(hostname -i)"
   SUBSONIC_HOME="${APPBASE}"
   SUBSONIC_CONTEXT_PATH="/subsonic"
   SUBSONIC_PORT=4040
   SUBSONIC_HTTPS_PORT=4141
   export SUBSONIC_HOST SUBSONIC_HOME SUBSONIC_CONTEXT_PATH SUBSONIC_DB SUBSONIC_PORT SUBSONIC_HTTPS_PORT SUBSONIC_MAX_MEMORY

   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting application container *****"
   if [ -z "${USER}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User name not set, defaulting to 'user'"; USER="user"; fi
   if [ -z "${UID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User ID not set, defaulting to '1000'"; UID="1000"; fi
   if [ -z "${GROUP}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group name not set, defaulting to 'group'"; GROUP="group"; fi
   if [ -z "${GID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Group ID not set, defaulting to '1000'"; GID="1000"; fi

   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local user: ${USER}:${UID}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local group: ${GROUP}:${GID}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic directory: ${SUBSONIC_HOME}"
   if [ -z "${SUBSONIC_MAX_MEMORY}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SUBSONIC_MAX_MEMORY not set, defaulting to 512MB"
      SUBSONIC_MAX_MEMORY="512"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SUBSONIC_MAX_MEMORY set to ${SUBSONIC_MAX_MEMORY}MB"
   fi

   if [ ! -z "${SUBSONIC_DEFAULT_MUSIC_FOLDER}" ]; then 
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic default music directory: ${SUBSONIC_DEFAULT_MUSIC_FOLDER}"
   fi

   if [ ! -z "${SUBSONIC_DEFAULT_PODCAST_FOLDER}" ]; then 
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic default music directory: ${SUBSONIC_DEFAULT_PODCAST_FOLDER}"
   fi

   if [ ! -z "${SUBSONIC_DEFAULT_PLAYLIST_FOLDER}" ]; then 
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic default music directory: ${SUBSONIC_DEFAULT_PLAYLIST_FOLDER}"
   fi

   if [ ! -f "${CONFIGDIR}/https" ]; then mkdir -p "${CONFIGDIR}/https"; fi
   if [ ! -f "${CONFIGDIR}/https/subsonic.pkcs12" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate private key for encrypting communications"
      openssl ecparam -genkey -name secp384r1 -out "${CONFIGDIR}/https/subsonic.key"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Create certificate request"
      openssl req -new -subj "/C=NA/ST=Global/L=Global/O=Subsonic/OU=Subsonic/CN=Subsonic/" -key "${CONFIGDIR}/https/subsonic.key" -out "${CONFIGDIR}/https/subsonic.csr"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Generate self-signed certificate request"
      openssl x509 -req -sha256 -days 3650 -in "${CONFIGDIR}/https/subsonic.csr" -signkey "${CONFIGDIR}/https/subsonic.key" -out "${CONFIGDIR}/https/subsonic.crt"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Convert to pkcs12 format"
      openssl pkcs12 -export -inkey "${CONFIGDIR}/https/subsonic.key" -in "${CONFIGDIR}/https/subsonic.crt" -out "${CONFIGDIR}/https/subsonic.pkcs12" -password pass:subsonic
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Create pkcs12 keystore"
      keytool -importkeystore -srckeystore "${CONFIGDIR}/https/subsonic.pkcs12" -srcstoretype PKCS12 -destkeystore "${APPBASE}/subsonic.keystore" -deststorepass subsonic -srcstorepass subsonic -noprompt
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Import keystore to Subsonic"
      zip -j "${APPBASE}/subsonic-booter-jar-with-dependencies.jar" "${APPBASE}/subsonic.keystore"
   fi

   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic available at: https://${SUBSONIC_HOST}:4040${SUBSONIC_CONTEXT_PATH}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuration directory: ${CONFIGDIR}"
}

CreateGroup(){
   if [ -z "$(getent group "${GROUP}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Group ID available, creating group"
      addgroup -g "${GID}" "${GROUP}"
   elif [ ! "$(getent group "${GROUP}" | cut -d: -f3)" = "${GID}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   Group GID mismatch - exiting"
      exit 1
   fi
}

CreateUser(){
   if [ -z "$(getent passwd "${USER}" | cut -d: -f3)" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    User ID available, creating user"
      adduser -s /bin/ash -H -D -G "${GROUP}" -u "${UID}" "${USER}"
   elif [ ! "$(getent passwd "${USER}" | cut -d: -f3)" = "${UID}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   User ID already in use - exiting"
      exit 1
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Correct owner and group of application files, if required"
   if [ ! -f "${APPBASE}/subsonic_sh.log" ]; then touch "${APPBASE}/subsonic_sh.log"; fi
   if [ ! -f "${APPBASE}/subsonic.log" ]; then touch "${APPBASE}/subsonic.log"; fi
   find "${APPBASE}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${APPBASE}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
   find "${CONFIGDIR}" ! -user "${USER}" -exec chown "${USER}" {} \;
   find "${CONFIGDIR}" ! -group "${GROUP}" -exec chgrp "${GROUP}" {} \;
}

LaunchSubsonic(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting Subsonic as ${USER}"
   su -m "${USER}" -c "${APPBASE}"'/subsonic.sh'
   tail -Fn0 "${APPBASE}/subsonic_sh.log" &
   tail -Fn0 "${APPBASE}/subsonic.log"
}

##### Script #####
Initialise
CreateGroup
CreateUser
SetOwnerAndGroup
LaunchSubsonic