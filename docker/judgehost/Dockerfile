FROM debian:bookworm
LABEL org.opencontainers.image.authors="DOMjudge team <team@domjudge.org>"

ENV DEBIAN_FRONTEND=noninteractive \
	CONTAINER_TIMEZONE=Europe/Amsterdam \
	DOMSERVER_BASEURL=http://domserver/ \
	JUDGEDAEMON_USERNAME=judgehost \
	JUDGEDAEMON_PASSWORD=password \
	DAEMON_ID=0 \
	DOMJUDGE_CREATE_WRITABLE_TEMP_DIR=0 \
	RUN_USER_UID_GID=62860

# Install required packages for running of judgehost
RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
	dumb-init pkg-config \
	acl lsof zip unzip supervisor sudo procps libcgroup2 \
	php-cli php-zip php-gd php-curl php-mysql php-json \
	php-gmp php-xml php-mbstring python3 \
	gcc g++ default-jre-headless default-jdk-headless ghc fp-compiler \
	&& rm -rf /var/lib/apt/lists/*

# Add chroot and judgehost data
ADD chroot.tar.gz /
ADD judgehost.tar.gz /
RUN cp /opt/domjudge/judgehost/etc/sudoers-domjudge /etc/sudoers.d/

# Add scripts
COPY judgehost/scripts /scripts/

# Make the scripts available to the root user
ENV PATH="$PATH:/opt/domjudge/judgehost/bin"

# Change start script permissions, add user and fix permissions
COPY judgehost/configure.sh /configure.sh
RUN chmod 700 /configure.sh && /configure.sh && rm -f /configure.sh

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/scripts/start.sh"]
