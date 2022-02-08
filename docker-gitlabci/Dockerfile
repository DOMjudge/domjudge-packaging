FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
ENV PHPSUPPORTED="7.2 7.3 8.0 8.1"
ENV APTINSTALL="apt install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
RUN apt update && apt install -y \
  acl make zip unzip apache2-utils bsdmainutils libcurl4-gnutls-dev \
  libjsoncpp-dev libmagic-dev autoconf automake bats sudo debootstrap procps \
  gcc g++ default-jre-headless default-jdk ghc fp-compiler libcgroup-dev \
  devscripts shellcheck nginx libboost-regex-dev \
  php7.4 php7.4-cli php7.4-gd php7.4-curl php7.4-mysql php7.4-json php7.4-gmp php7.4-zip php7.4-xml php7.4-mbstring php7.4-fpm php7.4-intl php7.4-pcov \
  # W3c test \
  httrack \
  # Visual regression browser \
  cutycapt xvfb openimageio-tools imagemagick \
  # Submit client \
  python3-requests python3-magic \
  # Docs \
  python3-sphinx python3-sphinx-rtd-theme rst2pdf fontconfig python3-yaml \
  texlive-latex-recommended texlive-latex-extra \
  texlive-fonts-recommended texlive-lang-european latexmk \
  # Misc gitlab things \
  mariadb-client curl build-essential packaging-dev  \
  git python3-pip moreutils w3m python3-yaml \
  # Things we'd have in the chroot \
  ca-certificates default-jre-headless pypy locales software-properties-common \
  # W3c WCAG \
  npm libnss3 libcups2 libxss1 libasound2 libatk1.0-0  libatk-bridge2.0-0 libpangocairo-1.0-0 libgtk-3-0 \
  # Code coverage for unit test
  php-pear php-dev \
  # Needed NPM packages \
  && npm install pa11y \
  # Needed python packages \
  && pip install codespell \
  && rm -rf /var/lib/apt/lists/*

# Install composer
RUN apt update && \
    apt install --no-install-recommends --no-install-suggests -y ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && php composer-setup.php \
    && mv /composer.phar /usr/local/bin/composer

# Install needed global PHP modules
RUN composer -n require justinrainbow/json-schema

# Install other PHP versions
RUN add-apt-repository ppa:ondrej/php -y && apt update && \
    PACKAGES=$(dpkg-query -f '${binary:Package}\n' -W|grep "^php.*-") && \
    for VERSION in $PHPSUPPORTED; do \
        $APTINSTALL php${VERSION} && \
        for PACKAGE in $PACKAGES; do \
            $APTINSTALL php${VERSION}-${PACKAGE#php*-}; \
        done; \
    done && update-alternatives --set php /usr/bin/php7.4

# Put the gitlab user in sudo
RUN echo 'ALL ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN useradd -m domjudge
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-0
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-1
RUN groupadd domjudge-run

# Do some extra setup
RUN mkdir -p /run/php \
 && rm /etc/php/*/fpm/pool.d/www.conf
