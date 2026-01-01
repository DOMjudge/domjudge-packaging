#!/bin/sh -eu

cd /domjudge-src/domjudge*
chown -R domjudge: .
# If we used a local source tarball, it might not have been built yet
sudo -u domjudge sh -c 'make dist'
sudo -u domjudge ./configure -with-baseurl=http://localhost/ --disable-judgehost-build

# Passwords should not be included in the built image. We create empty files here to prevent passwords from being generated.
sudo -u domjudge touch etc/dbpasswords.secret etc/restapi.secret etc/symfony_app.secret etc/initial_admin_password.secret

sudo -u domjudge make domserver docs
make install-domserver install-docs

# Remove installed password files
rm /opt/domjudge/domserver/etc/*.secret
