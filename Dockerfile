FROM alpine:latest
MAINTAINER boredazfcuk

ENV CONFIGDIR="/config" \
   APPBASE=/Subsonic \
	REPO="git://git.code.sf.net/p/subsonic/git" \
   DEPENDENCIES="tzdata openjdk8-jre fontconfig openssl zip ffmpeg lame mariadb-client"
#ttf-dejavu 

COPY start-subsonic.sh /usr/local/bin/start-subsonic.sh

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install application dependencies" && \
   apk add --no-cache --no-progress ${DEPENDENCIES} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Subsonic" && \
   mkdir -p "${APPBASE}/transcode/" "${APPBASE}/db/" "${CONFIGDIR}/db/" && \
   touch "${CONFIGDIR}/subsonic.properties" && \
   ln -s "${CONFIGDIR}/subsonic.properties" "${APPBASE}/" && \
   rm "${CONFIGDIR}/subsonic.properties" && \
   TEMP="$(mktemp -d)" && \
   SUBSONICLATEST="$(wget -qO- https://s3-eu-west-1.amazonaws.com/subsonic-public/download/checksums-sha256.txt | grep standalone | cut -d' ' -f 3 | sort -r | head -n 1)" && \
   wget -q "https://s3-eu-west-1.amazonaws.com/subsonic-public/download/${SUBSONICLATEST}" --directory-prefix="${TEMP}" && \
   tar xzf "${TEMP}/${SUBSONICLATEST}" -C "${APPBASE}" && \
   rm -r "${TEMP}" && \
   ln -s /usr/bin/ffmpeg "${APPBASE}/transcode/" && \
   ln -s /usr/bin/lame "${APPBASE}/transcode/" && \
   mv "${APPBASE}/db/" "${CONFIGDIR}" && \
   ln -s "${CONFIGDIR}/db/" "${APPBASE}/" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher" && \
   chmod +x /usr/local/bin/start-subsonic.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

VOLUME "${CONFIGDIR}"

CMD /usr/local/bin/start-subsonic.sh