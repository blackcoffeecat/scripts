#!/bin/bash

NGINXVER="$(sudo nginx -v 2>&1)"
NGINXVER="$(node -e "console.log('$NGINXVER'.match(/nginx\/([\d\.]+)$/)[1])")"
FILENAME="nginx-$NGINXVER.tar.gz"

cd /tmp
wget "http://nginx.org/download/$FILENAME"
tar zxf "$FILENAME"
git clone https://github.com/google/ngx_brotli.git
cd ngx_brotli
git submodule update --init
cd "../nginx-$NGINXVER"

./configure --with-compat --add-dynamic-module=../ngx_brotli
make

sudo cp objs/*.so /etc/nginx/modules
