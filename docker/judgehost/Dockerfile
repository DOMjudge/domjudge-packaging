FROM debian:latest
MAINTAINER DOMjudge team <team@domjudge.org>

ENV DEBIAN_FRONTEND=noninteractive \
	CONTAINER_TIMEZONE=Europe/Amsterdam \
	DOMSERVER_BASEURL=http://domserver/ \
	JUDGEDAEMON_USERNAME=judgehost \
	JUDGEDAEMON_PASSWORD=password \
	DAEMON_ID=0

# Install required packages for running of judgehost
RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
	zip unzip acl supervisor sudo procps libcgroup1 \
	php-cli php-zip php-gd php-curl php-mysql php-json \
	php-mcrypt php-gmp php-xml php-mbstring \
	gcc g++ openjdk-8-jre-headless openjdk-8-jdk ghc fp-compiler \
	&& rm -rf /var/lib/apt/lists/*

# Add chroot and judgehost data
ADD chroot.tar.gz /
ADD judgehost.tar.gz /
RUN cp /opt/domjudge/judgehost/etc/sudoers-domjudge /etc/sudoers.d/

# Add scripts
COPY ["judgehost/scripts", "/scripts/"]

# Change start script permissions, add user and group and fix permissions
RUN chmod +x /scripts/start.sh \
	&& useradd -m domjudge \
	&& groupadd domjudge-run \
	&& chown -R domjudge: /opt/domjudge
CMD ["/scripts/start.sh"]
