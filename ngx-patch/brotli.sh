#!/bin/bash

NGINXVER="$(nginx -v 2>&1 | cut -d "/" -f 2)"
FILENAME="nginx-$NGINXVER.tar.gz"

mkdir /tmp/ngxbrotli
cd /tmp/ngxbrotli
wget "http://nginx.org/download/$FILENAME"
tar zxf "$FILENAME"
git clone https://github.com/google/ngx_brotli.git
cd ngx_brotli
git submodule update --init
cd "../nginx-$NGINXVER"

./configure --with-compat --add-dynamic-module=../ngx_brotli
make

sudo cp objs/*.so /etc/nginx/modules
cd /tmp
rm -rf ngxbrotli
