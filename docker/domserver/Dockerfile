FROM ubuntu:24.04 AS domserver-build
LABEL org.opencontainers.image.authors="DOMjudge team <team@domjudge.org>"

ENV DEBIAN_FRONTEND=noninteractive

# Set up user
RUN useradd -m domjudge

# Install required packages for build of domserver
RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
	autoconf automake git make \
	acl zip unzip \
	php-cli php-zip php-bcmath \
	php-gd php-curl php-mysql php-json php-intl \
	php-gmp php-xml php-mbstring composer sudo \
	python3-sphinx python3-sphinx-rtd-theme fontconfig \
	texlive-latex-recommended texlive-latex-extra \
	texlive-fonts-recommended texlive-lang-european latexmk tex-gyre \
	enscript lpr \
	&& rm -rf /var/lib/apt/lists/*

# Add DOMjudge source code and build script
ADD domjudge.tar.gz /domjudge-src
COPY domserver/build.sh /domjudge-src/build.sh

# Build and install domserver
RUN /domjudge-src/build.sh

# Now create an image with the actual build in it
FROM ubuntu:24.04
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

# Set up user
RUN useradd -m domjudge

# Install required packages for running of domserver
RUN apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
	acl zip curl supervisor mariadb-client pv \
	nginx composer php-fpm php-zip php-bcmath \
	php-gd php-mysql php-json php-intl php-gmp \
	php-xml php-mbstring python3-yaml python3-requests enscript lpr \
	&& rm -rf /var/lib/apt/lists/*

# Check the UID and GID of the domjudge user are the same as in the previous build stage
# (otherwise the COPY directives below won't set the correct ownership)
COPY --from=domserver-build /etc/passwd /tmp/domserver-build-etc-passwd
RUN sed -i -n '/^domjudge:/p' /tmp/domserver-build-etc-passwd \
	&& sed -n '/^domjudge:/p' /etc/passwd | diff /tmp/domserver-build-etc-passwd - \
	|| { echo "error: UID/GID of 'domjudge' differ from previous build stage; they must be the same for COPY to work" >&2; exit 1; } \
	&& rm /tmp/domserver-build-etc-passwd

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
