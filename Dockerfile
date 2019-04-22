FROM archlinux/base:latest as buildstage
MAINTAINER sciencetaco

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="nzbget-nzbtomedia" \
      org.label-schema.description="Nzbget container with dependencies for nzbToMedia" \
      org.label-schema.url="https://github.com/sciencetaco/nzbget-nzbToMedia/" \
      org.label-schema.vendor="sciencetaco" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

RUN \
  pacman -Sy && \
  pacman -S --noconfirm \
    base-devel \
    libxml2 \
    git \
    vi \
    gcc \
    openssl \
    cmake && \
  echo "**** build nzbget ****" && \
 if [ -z ${NZBGET_RELEASE+x} ]; then \
	NZBGET_RELEASE=$(curl -sX GET "https://api.github.com/repos/nzbget/nzbget/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && \
 mkdir -p /app/nzbget && \
 git clone https://github.com/nzbget/nzbget.git nzbget && \
 cd nzbget/ && \
 git checkout ${NZBGET_RELEASE} && \
 git cherry-pick -n fa57474d && \
 ./configure \
	bindir='${exec_prefix}' && \
 make && \
 make prefix=/app/nzbget install && \
 sed -i \
        -e "s#^MainDir=.*#MainDir=/downloads#g" \
        -e "s#^ScriptDir=.*#ScriptDir=$\{MainDir\}/scripts#g" \
        -e "s#^WebDir=.*#WebDir=$\{AppDir\}/webui#g" \
        -e "s#^ConfigTemplate=.*#ConfigTemplate=$\{AppDir\}/webui/nzbget.conf.template#g" \
        -e "s#^UnrarCmd=.*#UnrarCmd=$\{AppDir\}/unrar#g" \
        -e "s#^SevenZipCmd=.*#SevenZipCmd=$\{AppDir\}/7za#g" \
        -e "s#^CertStore=.*#CertStore=$\{AppDir\}/cacert.pem#g" \
        -e "s#^CertCheck=.*#CertCheck=yes#g" \
        -e "s#^DestDir=.*#DestDir=$\{MainDir\}/completed#g" \
        -e "s#^InterDir=.*#InterDir=$\{MainDir\}/intermediate#g" \
        -e "s#^LogFile=.*#LogFile=$\{MainDir\}/nzbget.log#g" \
        -e "s#^AuthorizedIP=.*#AuthorizedIP=127.0.0.1#g" \
 /app/nzbget/share/nzbget/nzbget.conf && \
 mv /app/nzbget/share/nzbget/webui /app/nzbget/ && \
 cp /app/nzbget/share/nzbget/nzbget.conf /app/nzbget/webui/nzbget.conf.template && \
 ln -s /usr/bin/7za /app/nzbget/7za && \
 ln -s /usr/bin/unrar /app/nzbget/unrar && \
 cp /nzbget/pubkey.pem /app/nzbget/pubkey.pem && \
 curl -o \
	/app/nzbget/cacert.pem -L \
	"https://curl.haxx.se/ca/cacert.pem"

# Runtime Stage
FROM archlinux/base:latest 

RUN \
 echo "**** install packages ****" && \
 pacman -Sy && \
 pacman -S --noconfirm \
    curl \
    libxml2 \
    openssl \
    p7zip \
    python2 \
    python2-pip \
    unrar \
    tar \
    par2cmdline \
    procps-ng \
    wget && \

  pip2 install requests[security] && \
  pip2 install requests-cache && \
  pip2 install babelfish && \
  pip2 install "guessit<2" && \
  pip2 install deluge-client && \
  pip2 install qtfaststart && \
  pip2 install "subliminal<2" && \
  pip2 install stevedore==1.19.1 

# add local files and files from buildstage
COPY --from=buildstage /app/nzbget /app/nzbget

COPY root/ /

# ports and volumes
VOLUME /config /downloads
EXPOSE 6789
