FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  acl make zip unzip apache2-utils bsdmainutils libcurl4-gnutls-dev \
  libjsoncpp-dev libmagic-dev autoconf automake bats sudo debootstrap procps \
  gcc g++ default-jre-headless default-jdk ghc fp-compiler libcgroup-dev \
  devscripts shellcheck nginx libboost-regex-dev \
  php php-cli php-gd php-curl php-mysql php-json php-gmp php-zip php-xml php-mbstring php-fpm php-intl \
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
  && pecl install pcov \
  # Needed NPM packages \
  && npm install pa11y \
  && rm -rf /var/lib/apt/lists/*

# Install composer
RUN apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && php composer-setup.php \
    && mv /composer.phar /usr/local/bin/composer

# Enable pcov (code coverage) in PHP
COPY php-config/30-pcov.ini /etc/php/7.4/cli/conf.d/

# Put the gitlab user in sudo
RUN echo 'ALL ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN useradd -m domjudge
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-0
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-1
RUN groupadd domjudge-run

# Do some extra setup
RUN mkdir -p /run/php \
 && rm /etc/php/7.4/fpm/pool.d/www.conf
