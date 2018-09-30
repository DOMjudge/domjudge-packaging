FROM debian:latest
MAINTAINER DOMjudge team <team@domjudge.org>

ENV DEBIAN_FRONTEND=noninteractive \
  CONTAINER_TIMEZONE=Europe/Amsterdam \
  MYSQL_HOST=mariadb \
  MYSQL_USER=domjudge \
  MYSQL_DATABASE=domjudge \
  MYSQL_PASSWORD=domjudge \
  MYSQL_ROOT_PASSWORD=domjudge \
  DJ_SKIP_MAKE=0 \
  DJ_DB_INSTALL_BARE=0

# Install required packages and clean up afterwards to make this image layer smaller
RUN apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
    autoconf automake git acl \
    gcc g++ make zip unzip mariadb-client \
    nginx php php-cli php-fpm php-zip \
    php-gd php-curl php-mysql php-json php-intl \
    php-mcrypt php-gmp php-xml php-mbstring \
    bsdmainutils ntp \
    linuxdoc-tools linuxdoc-tools-text \
    groff texlive-latex-recommended texlive-latex-extra \
    texlive-fonts-recommended texlive-lang-european \
    sudo debootstrap libcgroup-dev procps \
    openjdk-8-jre-headless \
    openjdk-8-jdk ghc fp-compiler \
    supervisor apache2-utils lsb-release \
    libcurl4-gnutls-dev libjsoncpp-dev libmagic-dev python python-pip \
    enscript lpr \
    && pip install Pygments \
    && rm -rf /var/lib/apt/lists/*

# Forward nginx request and error logs to standard output/error. Also create directory for PHP-FPM socket
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
  && mkdir -p /run/php

# Set up users
RUN useradd -m domjudge \
  && groupadd domjudge-run \
  && useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-0 \
  && useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-1

# Install composer
ADD https://getcomposer.org/installer composer-setup.php
RUN php composer-setup.php \
    && mv /composer.phar /usr/local/bin/composer

# Add exposed volume
VOLUME ["/domjudge"]

WORKDIR /domjudge

# Add scripts
COPY ["scripts", "/scripts/"]
RUN chmod 755 /scripts/start.sh \
  && chmod 755 /scripts/bin/* \
  && ln -s /scripts/bin/* /usr/bin/
CMD ["/scripts/start.sh"]

# Copy supervisor files
COPY ["supervisor", "/etc/supervisor/conf.d/"]

# Expose HTTP port
EXPOSE 80
