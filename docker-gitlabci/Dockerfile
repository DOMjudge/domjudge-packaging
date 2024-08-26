FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV PHPSUPPORTED="7.4 8.0 8.1 8.2"
ENV APTINSTALL="apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
RUN useradd -m domjudge
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-0
RUN useradd -d /nonexistent -g nogroup -s /bin/false domjudge-run-1
RUN groupadd domjudge-run

RUN apt-get update && apt-get install -y \
  acl make zip unzip apache2-utils bsdmainutils libcurl4-gnutls-dev \
  libjsoncpp-dev libmagic-dev autoconf automake bats sudo debootstrap procps \
  gcc g++ default-jre-headless default-jdk-headless ghc fp-compiler libcgroup-dev \
  devscripts shellcheck nginx libboost-regex-dev composer codespell \
  php8.3 php8.3-cli php8.3-gd php8.3-curl php8.3-mysql php8.3-gmp php8.3-zip php8.3-xml php8.3-mbstring php8.3-fpm php8.3-intl php8.3-pcov \
  # Submit client \
  python3-requests python3-magic \
  # Docs \
  python3-sphinx python3-sphinx-rtd-theme rst2pdf fontconfig python3-yaml \
  texlive-latex-recommended texlive-latex-extra texlive-lang-european latexmk \
  # Misc gitlab things \
  mariadb-client curl build-essential packaging-dev  \
  git python3-pip moreutils w3m python3-yaml \
  # Things we'd have in the chroot \
  ca-certificates default-jre-headless pypy3 locales software-properties-common \
  # W3c WCAG \
  npm \
  # Code coverage for unit test \
  php-pear php-dev \
  && rm -rf /var/lib/apt/lists/*

# Install needed NPM packages and download chrome for the domjudge user
RUN su domjudge -c "cd /home/domjudge && \
                    npm install pa11y puppeteer && \
                    npx puppeteer browsers install chrome && \
                    npm cache clean --force"

# Install needed global PHP modules
RUN composer -n require justinrainbow/json-schema

# Install other PHP versions
RUN add-apt-repository ppa:ondrej/php -y && apt-get update && \
    PACKAGES=$(dpkg-query -f '${binary:Package}\n' -W|grep "^php.*-") && \
    for VERSION in $PHPSUPPORTED; do \
        $APTINSTALL php${VERSION} && \
        for PACKAGE in $PACKAGES; do \
            $APTINSTALL php${VERSION}-${PACKAGE#php*-}; \
        done; \
    done && update-alternatives --set php /usr/bin/php8.3 \
    && rm -rf /var/lib/apt/lists/*

# Put the gitlab user in sudo
RUN echo 'ALL ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Update dictionary to latest version
ENV GITHUBDICTIONARY="https://raw.githubusercontent.com/codespell-project/codespell/master/codespell_lib/data/dictionary.txt"
ENV CODESPELLDICTLOCATION="/usr/lib/python3/dist-packages/codespell_lib/data/dictionary.txt"
RUN wget $GITHUBDICTIONARY -O $CODESPELLDICTLOCATION

# Do some extra setup
RUN mkdir -p /run/php \
 && rm /etc/php/*/fpm/pool.d/www.conf
