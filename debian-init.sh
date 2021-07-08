#!/bin/bash

# https://github.com/nodesource/distributions#debinstall
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -

sudo apt install curl gnupg2 ca-certificates lsb-release nodejs geoip-bin -y

IP="$(curl -s icanhazip.com)"
GEOLOCATION="$(geoiplookup "$IP")"
COUNTRY="$(node -e "console.log('$GEOLOCATION'.match(/: ([A-Z]+),/)[1])")"

CODENAME="$(lsb_release -cs)"

# https://nginx.org/en/linux_packages.html#Debian
echo "deb http://nginx.org/packages/mainline/debian $CODENAME nginx" \
  | sudo tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
  | sudo tee /etc/apt/preferences.d/99nginx
curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key
gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc

# https://unix.stackexchange.com/questions/310222/
echo -e "Package: *\nPin: release a=$CODENAME-backports\nPin-Priority: 800\n" \
  | sudo tee /etc/apt/preferences.d/backports
echo -e "deb http://ftp.debian.org/debian $CODENAME-backports main contrib non-free" \
  | sudo tee -a /etc/apt/sources.list
echo -e "deb-src http://ftp.debian.org/debian $CODENAME-backports main contrib non-free" \
  | sudo tee -a /etc/apt/sources.list

# https://wiki.postgresql.org/wiki/Apt#Quickstart
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $CODENAME-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

sudo apt update
sudo DEBIAN_FRONTEND='noninteractive' \
  apt -y \
  -o Dpkg::Options::='--force-confdef' \
  -o Dpkg::Options::='--force-confold' \
  upgrade

sudo apt install --allow-downgrades -y \
  nginx mariadb-server postgresql \
  git wget brotli libcurl3-gnutls/stable \
  build-essential libpcre3 libpcre3-dev zlib1g-dev

apt-get autoremove -y
apt-get clean
apt-get autoclean

sudo sed '5 a load_module modules/ngx_http_brotli_filter_module.so;' /etc/nginx/nginx.conf
sudo sed '5 a load_module modules/ngx_http_brotli_static_module.so;' /etc/nginx/nginx.conf

sudo curl -o /etc/nginx/conf.d/nginx.http.conf https://blackcoffeecat.github.io/scripts/nginx.http.conf

curl -fsSL https://blackcoffeecat.github.io/scripts/upgrade-nginx.sh | bash -
