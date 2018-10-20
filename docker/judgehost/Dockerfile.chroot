FROM ubuntu:18.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install \
  ca-certificates default-jre-headless pypy locales \
  software-properties-common \
  && rm -rf /var/lib/apt/lists/*

RUN chmod a-s \
  /usr/bin/wall \
  /usr/bin/newgrp \
  /usr/bin/chage \
  /usr/bin/chfn \
  /usr/bin/chsh \
  /usr/bin/expiry \
  /usr/bin/gpasswd \
  /usr/bin/passwd \
  /bin/su \
  /bin/mount \
  /bin/umount \
  /sbin/unix_chkpwd \
  || true
