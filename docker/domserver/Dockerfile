FROM debian:latest AS domserver-build
MAINTAINER DOMjudge team <team@domjudge.org>

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages for build of domserver
RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
	autoconf automake git \
	gcc g++ make acl zip unzip \
	php-cli php-zip \
	php-gd php-curl php-mysql php-json php-intl \
	php-gmp php-xml php-mbstring \
	sudo bsdmainutils ntp libcgroup-dev procps \
	linuxdoc-tools linuxdoc-tools-text groff \
	python3-sphinx python3-sphinx-rtd-theme python3-pip fontconfig python3-yaml \
	texlive-latex-recommended texlive-latex-extra \
	texlive-fonts-recommended texlive-lang-european \
	libcurl4-gnutls-dev libjsoncpp-dev libmagic-dev \
	enscript lpr ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# Needed for building the docs
RUN pip3 install pygments rst2pdf

# Set up user
RUN useradd -m domjudge

# Install composer
RUN php -r "copy('http://getcomposer.org/installer', 'composer-setup.php');" && php composer-setup.php \
    && mv /composer.phar /usr/local/bin/composer

# Add DOMjudge source code and build script
ADD domjudge.tar.gz /domjudge-src
ADD domserver/build.sh /domjudge-src

# Build and install domserver
RUN /domjudge-src/build.sh

# Now create an image with the actual build in it
FROM debian:latest
MAINTAINER DOMjudge team <team@domjudge.org>

ENV DEBIAN_FRONTEND=noninteractive \
	CONTAINER_TIMEZONE=Europe/Amsterdam \
	MYSQL_HOST=mariadb \
	MYSQL_USER=domjudge \
	MYSQL_DATABASE=domjudge \
	MYSQL_PASSWORD=domjudge \
	MYSQL_ROOT_PASSWORD=domjudge \
	FPM_MAX_CHILDREN=40 \
	DJ_DB_INSTALL_BARE=0

# Install required packages for running of domserver
RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
	acl zip unzip supervisor mariadb-client apache2-utils \
	nginx php-cli php-fpm php-zip \
	php-gd php-curl php-mysql php-json php-intl \
	php-gmp php-xml php-mbstring php-ldap \
	enscript lpr \
	&& rm -rf /var/lib/apt/lists/*

# Install composer
RUN php -r "copy('http://getcomposer.org/installer', 'composer-setup.php');" && php composer-setup.php \
    && mv /composer.phar /usr/local/bin/composer

# Copy domserver directory and add script files
COPY --from=domserver-build /opt/domjudge/domserver /opt/domjudge/domserver
COPY --from=domserver-build /opt/domjudge/doc /opt/domjudge/doc
COPY ["domserver/scripts", "/scripts/"]

# Add user, create PHP FPM socket dir, change permissions for domjudge directory and fix scripts
RUN useradd -m domjudge \
	&& mkdir -p /run/php \
	&& chown -R domjudge: /opt/domjudge \
	&& chown -R www-data: /opt/domjudge/domserver/tmp \
	# for DOMjudge <= 7.2 (submitdir was removed in commit DOMjudge/domjudge@d66725038)
	&& if [ -d /opt/domjudge/domserver/submissions ]; then chown -R www-data: /opt/domjudge/domserver/submissions; fi \
	&& chmod 755 /scripts/start.sh \
	&& chmod 755 /scripts/bin/* \
	&& ln -s /scripts/bin/* /usr/bin/
CMD ["/scripts/start.sh"]

# Copy supervisor files
COPY ["domserver/supervisor", "/etc/supervisor/conf.d/"]

# Expose HTTP port
EXPOSE 80
