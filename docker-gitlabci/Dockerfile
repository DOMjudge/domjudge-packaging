FROM ubuntu:18.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  acl make zip unzip apache2-utils bsdmainutils libcurl4-gnutls-dev \
  libjsoncpp-dev libmagic-dev autoconf automake bats sudo debootstrap procps \
  gcc g++ default-jre-headless default-jdk ghc fp-compiler libcgroup-dev \
  devscripts shellcheck nginx libboost-regex-dev \
  php php-cli php-gd php-curl php-mysql php-json php-gmp php-zip php-xml php-mbstring php-fpm php-intl \
  # W3c test \
  httrack \
  # Docs \
  python-sphinx python-sphinx-rtd-theme rst2pdf fontconfig python3-yaml \
  texlive-latex-recommended texlive-latex-extra \
  texlive-fonts-recommended texlive-lang-european \
  # Misc gitlab things \
  mariadb-client curl build-essential composer packaging-dev  \
  git python-pip moreutils \
  # Things we'd have in the chroot \
  ca-certificates default-jre-headless pypy locales software-properties-common \
  # W3c WCAG \
  npm libx11-xcb-dev libxtst-dev libnss3-dev libxss-dev libasound2-dev libatk-bridge2.0-dev libgtk-3-dev \
  # Needed NPM packages \
  npm install -g pa11y \
  && rm -rf /var/lib/apt/lists/*

# Put the gitlab user in sudo
RUN echo 'ALL ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN useradd -m domjudge
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-0
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-1
RUN groupadd domjudge-run

# Do some extra setup
RUN mkdir -p /run/php \
 && rm /etc/php/7.2/fpm/pool.d/www.conf
