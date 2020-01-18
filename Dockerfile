FROM alpine:latest
MAINTAINER boredazfcuk
ARG app_dependencies="tzdata openjdk8-jre fontconfig openssl zip ffmpeg lame mariadb-client wget"
ENV config_dir="/config" \
   app_base_dir=/Subsonic

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install application dependencies" && \
   apk add --no-cache --no-progress ${app_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Subsonic" && \
   mkdir -p "${app_base_dir}/transcode/" "${app_base_dir}/db/" "${config_dir}/db/" && \
   touch "${config_dir}/subsonic.properties" && \
   ln -s "${config_dir}/subsonic.properties" "${app_base_dir}/" && \
   rm "${config_dir}/subsonic.properties" && \
   temp_dir="$(mktemp -d)" && \
   subsonic_latest_version="$(wget -qO- https://s3-eu-west-1.amazonaws.com/subsonic-public/download/checksums-sha256.txt | grep standalone | cut -d' ' -f 3 | sort -r | head -n 1)" && \
   wget -q "https://s3-eu-west-1.amazonaws.com/subsonic-public/download/${subsonic_latest_version}" --directory-prefix="${temp_dir}" && \
   tar xzf "${temp_dir}/${subsonic_latest_version}" -C "${app_base_dir}" && \
   rm -r "${temp_dir}" && \
   ln -s /usr/bin/ffmpeg "${app_base_dir}/transcode/" && \
   ln -s /usr/bin/lame "${app_base_dir}/transcode/" && \
   mv "${app_base_dir}/db/" "${config_dir}" && \
   ln -s "${config_dir}/db/" "${app_base_dir}/"

COPY start-subsonic.sh /usr/local/bin/start-subsonic.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher" && \
   chmod +x /usr/local/bin/start-subsonic.sh /usr/local/bin/healthcheck.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
   CMD /usr/local/bin/healthcheck.sh

VOLUME "${config_dir}"
WORKDIR "${app_base_dir}"

CMD /usr/local/bin/start-subsonic.sh