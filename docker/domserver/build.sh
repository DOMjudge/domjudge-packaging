#!/bin/bash -e

cd /domjudge-src/domjudge*
chown -R domjudge: .
sudo -u domjudge ./configure -with-baseurl=http://localhost/
sudo -u domjudge make domserver
make install-domserver
sudo -u domjudge make docs
make install-docs
