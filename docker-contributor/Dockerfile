ARG ARCH=
FROM "${ARCH}ubuntu:focal"
LABEL maintainer="DOMjudge team <team@domjudge.org>"

ENV DEBIAN_FRONTEND=noninteractive \
  CONTAINER_TIMEZONE=Europe/Amsterdam \
  MYSQL_HOST=mariadb \
  MYSQL_USER=domjudge \
  MYSQL_DATABASE=domjudge \
  MYSQL_PASSWORD=domjudge \
  MYSQL_ROOT_PASSWORD=domjudge \
  FPM_MAX_CHILDREN=40 \
  DJ_SKIP_MAKE=0 \
  DJ_DB_INSTALL_BARE=0 \
  PHPSUPPORTED="7.2 7.3 7.4 8.0 8.1" \
  DEFAULTPHPVERSION="8.1" \
  APTINSTALL="apt install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

# Install required packages and clean up afterwards to make this image layer smaller
RUN apt update \
    && apt install --no-install-recommends --no-install-suggests -y \
    dumb-init autoconf automake git acl \
    gcc g++ make zip unzip mariadb-client \
    nginx php7.4 php7.4-cli php7.4-fpm php7.4-zip \
    php7.4-gd php7.4-curl php7.4-mysql php7.4-json php7.4-intl \
    php7.4-gmp php7.4-xml php7.4-mbstring php7.4-xdebug php7.4-pcov \
    bsdmainutils ntp \
    linuxdoc-tools linuxdoc-tools-text groff \
    python3-sphinx python3-sphinx-rtd-theme python3-pip fontconfig python3-yaml \
    texlive-latex-recommended texlive-latex-extra \
    texlive-fonts-recommended texlive-lang-european latexmk \
    sudo debootstrap libcgroup-dev procps \
    default-jre-headless default-jdk \
    supervisor apache2-utils lsb-release \
    libcurl4-gnutls-dev libjsoncpp-dev libmagic-dev \
    enscript lpr ca-certificates less vim \
    php-pear php-dev software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Needed for building the docs
RUN pip3 install pygments && pip3 install rst2pdf

# Forward nginx request and error logs to standard output/error. Also create directory for PHP-FPM socket
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
  && mkdir -p /run/php

# Set up users
RUN useradd -m domjudge \
  && groupadd domjudge-run \
  && for id in $(seq 0 4); do useradd -d /nonexistent -g nogroup -s /bin/false "domjudge-run-$id"; done

# Install composer
RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && php composer-setup.php \
    && mv /composer.phar /usr/local/bin/composer

# Install all supported PHP versions
RUN add-apt-repository ppa:ondrej/php -y && apt update
RUN for VERSION in $PHPSUPPORTED; do \
        if [ "${VERSION}" != "7.4" ]; then \
            $APTINSTALL php${VERSION}; \
        fi; \
    done
RUN PACKAGES=$(dpkg-query -f '${binary:Package}\n' -W|grep "^php.*-"); \
    for PACKAGE in $PACKAGES; do \
        PACKAGEALLVERSIONS="" && \
        for VERSION in $PHPSUPPORTED; do \
            if [ "${VERSION}" != "7.4" ]; then \
                PACKAGEALLVERSIONS="$PACKAGEALLVERSIONS php${VERSION}-${PACKAGE#php*-}"; \
            fi; \
        done; \
        $APTINSTALL $PACKAGEALLVERSIONS; \
    done
RUN update-alternatives --set php /usr/bin/php${DEFAULTPHPVERSION}

# Set up alternatives for PHP-FPM
RUN for VERSION in $PHPSUPPORTED; do \
        PRIORTIY=$(echo ${VERSION} | tr -d '.'); \
        update-alternatives --install /usr/sbin/php-fpm php-fpm /usr/sbin/php-fpm${VERSION} ${PRIORTIY}; \
    done
RUN update-alternatives --set php-fpm /usr/sbin/php-fpm${DEFAULTPHPVERSION}

# Add exposed volume
VOLUME ["/domjudge"]

WORKDIR /domjudge

# Add PHP configuration
RUN mkdir /php-config
COPY ["php-config", "/php-config"]
RUN for VERSION in $PHPSUPPORTED; do \
        cp -Rf /php-config/* /etc/php/${VERSION}/cli/conf.d; \
        cp -Rf /php-config/* /etc/php/${VERSION}/fpm/conf.d; \
    done; \ 
    rm -Rf /php-config

# Disable Xdebug by default
RUN phpdismod xdebug

# Add scripts
COPY ["scripts", "/scripts/"]
RUN chmod 755 /scripts/start.sh \
  && chmod 755 /scripts/bin/* \
  && ln -s /scripts/bin/* /usr/bin/
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/scripts/start.sh"]

# Copy supervisor files
COPY ["supervisord.conf", "/etc/supervisor/"]
COPY ["supervisor", "/etc/supervisor/conf.d/"]
COPY ["sudoers-domjudge", "/etc/sudoers.d/domjudge"]
RUN chmod 440 /etc/sudoers.d/domjudge

# Expose HTTP port
EXPOSE 80
