#!/bin/bash -e

# shellcheck disable=SC2154
sed -i "s!fastcgi_param *REMOTE_USER *$remote_user;!fastcgi_param REMOTE_USER $http_remote_user;!g" /etc/nginx/fastcgi_params
echo 'underscores_in_headers on;' >> /etc/nginx/snippets/domjudge-inner
