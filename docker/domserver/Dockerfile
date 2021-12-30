FROM debian:stable-slim AS domserver-build
LABEL org.opencontainers.image.authors="DOMjudge team <team@domjudge.org>"

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages for build of domserver
RUN apt update \
	&& apt install --no-install-recommends --no-install-suggests -y \
	autoconf automake git \
	gcc g++ make acl zip unzip \
	php-cli php-zip \
	php-gd php-curl php-mysql php-json php-intl \
	php-gmp php-xml php-mbstring \
	sudo bsdmainutils ntp libcgroup-dev procps \
	python3-sphinx python3-sphinx-rtd-theme python3-pip fontconfig python3-yaml \
	texlive-latex-recommended texlive-latex-extra \
	texlive-fonts-recommended texlive-lang-european latexmk \
	libcurl4-gnutls-dev libjsoncpp-dev libmagic-dev \
	enscript lpr ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# Needed for building the docs
RUN pip3 install pygments rst2pdf

# Set up user
RUN useradd -m domjudge

# Install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
	&& php composer-setup.php \
	&& mv /composer.phar /usr/local/bin/composer

# Add DOMjudge source code and build script
ADD domjudge.tar.gz /domjudge-src
COPY domserver/build.sh /domjudge-src/build.sh

# Build and install domserver
RUN /domjudge-src/build.sh

# Now create an image with the actual build in it
FROM debian:stable-slim
LABEL org.opencontainers.image.authors="DOMjudge team <team@domjudge.org>"

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
RUN apt update \
	&& apt install --no-install-recommends --no-install-suggests -y \
	acl curl zip unzip supervisor mariadb-client apache2-utils \
	nginx php-cli php-fpm php-zip \
	php-gd php-curl php-mysql php-json php-intl \
	php-gmp php-xml php-mbstring php-ldap \
	enscript lpr \
	ca-certificates python3-yaml \
	&& rm -rf /var/lib/apt/lists/*

# Install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
	&& php composer-setup.php \
	&& mv /composer.phar /usr/local/bin/composer

# Copy domserver
COPY --from=domserver-build /opt/domjudge/domserver /opt/domjudge/domserver
COPY --from=domserver-build /opt/domjudge/doc /opt/domjudge/doc

# Copy scripts
COPY domserver/scripts /scripts/
COPY domserver/supervisor /etc/supervisor/conf.d/

# Make the scripts available to the root user
ENV PATH="$PATH:/opt/domjudge/domserver/bin"

# Run customizations
COPY domserver/configure.sh /configure.sh
RUN chmod 700 /configure.sh && /configure.sh && rm -f /configure.sh

# Expose HTTP port
EXPOSE 80

# Healthchecking script
HEALTHCHECK --interval=10s --timeout=10s --start-period=30s --retries=3 CMD [ "/scripts/bin/healthcheck" ]

CMD ["/scripts/start.sh"]
