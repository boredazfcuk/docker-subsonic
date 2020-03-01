FROM alpine:latest
MAINTAINER boredazfcuk
ARG app_dependencies="tzdata openjdk8-jre fontconfig openssl zip ffmpeg lame mariadb-client wget"
ENV config_dir="/config" \
   app_base_dir="/Subsonic"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install application dependencies" && \
   apk add --no-cache --no-progress ${app_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Subsonic" && \
   mkdir -p "${app_base_dir}" && \
   temp_dir="$(mktemp -d)" && \
   subsonic_latest_version="$(wget -qO- https://s3-eu-west-1.amazonaws.com/subsonic-public/download/checksums-sha256.txt | grep standalone | cut -d' ' -f 3 | sort -r | head -n 1)" && \
   wget -q "https://s3-eu-west-1.amazonaws.com/subsonic-public/download/${subsonic_latest_version}" --directory-prefix="${temp_dir}" && \
   tar xzf "${temp_dir}/${subsonic_latest_version}" -C "${app_base_dir}" && \
   rm -r "${temp_dir}"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher" && \
   chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
   CMD /usr/local/bin/healthcheck.sh

VOLUME "${config_dir}"
WORKDIR "${app_base_dir}"

ENTRYPOINT /usr/local/bin/entrypoint.sh