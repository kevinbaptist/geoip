############################################################
# Dockerfile to create GeoLite2 Country and City databases
# with automatic weekly updates.
#
# Adapted from tkrs/maxmind-lite2-db and 
# tkrs/maxmind-geoipupdate by Takeru Sato.
############################################################

FROM alpine

MAINTAINER Tom Callahan <tcallahan@controlscan.com>
ARG license

### DOWNLOAD DATABASES

ENV GEOIP_BASE_URL      http://geolite.maxmind.com/download/geoip/database
ENV GEOIP_CNTR_DB       GeoLite2-Country_20200324.tar
ENV GEOIP_CITY_DB       GeoLite2-City_20200324.tar
ENV GEOIP_DB_DIR        /usr/share/GeoIP
ENV GEOIPUPDATE_VER     "4.0.6"
ENV YOUR_LICENSE_KEY    $license

# download gzip database files to /tmp/
ADD https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${YOUR_LICENSE_KEY}&suffix=tar.gz /tmp/${GEOIP_CNTR_DB}.gz
ADD https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${YOUR_LICENSE_KEY}&suffix=tar.gz /tmp/${GEOIP_CITY_DB}.gz

# unzip databases into database directory
RUN mkdir -p ${GEOIP_DB_DIR} \
 && gunzip -c /tmp/${GEOIP_CNTR_DB}.gz > ${GEOIP_DB_DIR}/${GEOIP_CNTR_DB} \
 && gunzip -c /tmp/${GEOIP_CITY_DB}.gz > ${GEOIP_DB_DIR}/${GEOIP_CITY_DB} \
 && rm -f /tmp/GeoLite2-*

VOLUME ${GEOIP_DB_DIR}


### INSTALL GEOIPUPDATE

# copy geoipupdate settings
COPY GeoIP.conf /usr/etc/GeoIP.conf

# install geoipupdate
RUN BUILD_DEPS='gcc make libc-dev libtool automake autoconf git' \
 && apk --no-cache add curl-dev ${BUILD_DEPS} \
 && apk update \
 && apk add ca-certificates \
 && update-ca-certificates \
 && apk add openssl \
 && wget -O /tmp/geoipupdate.tgz https://github.com/maxmind/geoipupdate/releases/download/v${GEOIPUPDATE_VER}/geoipupdate_${GEOIPUPDATE_VER}_linux_amd64.tar.gz \
 && tar -zxpvf /tmp/geoipupdate.tgz -C /opt/ \
 && cp /opt/geoipupdate_${GEOIPUPDATE_VER}_linux_amd64/geoipupdate /usr/bin/geoipupdate \
 && apk del --purge ${BUILD_DEPS} \
 && rm -rf /var/cache/apk/* \
 && rm -rf /tmp/geoipupdate.tgz \
 && rm -rf /opt/geoipupdate_${GEOIPUPDATE_VER}_linux_amd64

### CONFIGURE AUTOMATIC UPDATES

# copy crontab for running updates
COPY cronfile /var/spool/cron/crontabs/root

# run crond in foreground
ENTRYPOINT ["crond", "-f"]

# set crond options: log to stderr with log level 8
CMD ["-d", "8"]
