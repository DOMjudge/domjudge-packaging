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
  firefox openimageio-tools imagemagick \
  # Docs \
  python3-sphinx python3-sphinx-rtd-theme rst2pdf fontconfig python3-yaml \
  texlive-latex-recommended texlive-latex-extra \
  texlive-fonts-recommended texlive-lang-european \
  # Misc gitlab things \
  mariadb-client curl build-essential composer packaging-dev  \
  git python3-pip moreutils w3m \
  # Things we'd have in the chroot \
  ca-certificates default-jre-headless pypy locales software-properties-common \
  # W3c WCAG \
  npm libnss3 libcups2 libxss1 libasound2 libatk1.0-0  libatk-bridge2.0-0 libpangocairo-1.0-0 libgtk-3-0 \
  # Needed NPM packages \
  && npm install pa11y \
  && rm -rf /var/lib/apt/lists/*

# Put the gitlab user in sudo
RUN echo 'ALL ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN useradd -m domjudge
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-0
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-1
RUN groupadd domjudge-run

# Do some extra setup
RUN mkdir -p /run/php \
 && rm /etc/php/7.4/fpm/pool.d/www.conf
