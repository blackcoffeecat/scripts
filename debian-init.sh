#!/bin/bash

echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/nopasswd
echo -e "nameserver  223.5.5.5 \n" "nameserver  1.1.1.1 \n" | sudo tee -a /etc/resolv.conf

sudo apt install curl git wget gnupg2 ca-certificates lsb-release geoip-bin unzip htop iftop -y

# https://github.com/nodesource/distributions#debinstall
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install nodejs -y
sudo npm i -g npm yarn pm2 --registry=https://registry.npmmirror.com

IP="$(curl -s icanhazip.com)"
GEOLOCATION="$(geoiplookup "$IP")"
COUNTRY="$(node -p "'$GEOLOCATION'.match(/: ([A-Z]+),/)[1]")"
CODENAME="$(lsb_release -cs)"

if "$COUNTRY" == "CN"; then
  sudo mv /etc/apt/sources.list /etc/apt/sources.list.bk
  echo -e "deb http://mirrors.ustc.edu.cn/debian $CODENAME main" \
    "\ndeb-src http://mirrors.ustc.edu.cn/debian $CODENAME main" \
    "\ndeb http://mirrors.ustc.edu.cn/debian-security $CODENAME/updates main" \
    "\ndeb-src http://mirrors.ustc.edu.cn/debian-security $CODENAME/updates main" \
    "\ndeb http://mirrors.ustc.edu.cn/debian $CODENAME-updates main" \
    "\ndeb-src http://mirrors.ustc.edu.cn/debian $CODENAME-updates main" \
    "\ndeb http://mirrors.ustc.edu.cn/debian $CODENAME-backports main contrib non-free" \
    "\ndeb-src http://mirrors.ustc.edu.cn/debian $CODENAME-backports main contrib non-free" |
    sudo tee /etc/apt/sources.list
fi

# https://nginx.org/en/linux_packages.html#Debian
echo "deb http://nginx.org/packages/mainline/debian $CODENAME nginx" |
  sudo tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900" |
  sudo tee /etc/apt/preferences.d/99nginx
echo -e "Package: libcurl3-gnutls\nPin: version 7.64.*\nPin-Priority: 900\n" |
  sudo tee /etc/apt/preferences.d/00curl
curl -o /tmp/nginx_signing.key https://nginx.org/keys/nginx_signing.key
gpg --dry-run --quiet --import --import-options import-show /tmp/nginx_signing.key
mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc

# https://unix.stackexchange.com/questions/310222/
echo -e "Package: *\nPin: release a=$CODENAME-backports\nPin-Priority: 800\n" |
  sudo tee /etc/apt/preferences.d/backports
echo -e "deb http://ftp.debian.org/debian $CODENAME-backports main contrib non-free" |
  sudo tee -a /etc/apt/sources.list
echo -e "deb-src http://ftp.debian.org/debian $CODENAME-backports main contrib non-free" |
  sudo tee -a /etc/apt/sources.list

# https://wiki.postgresql.org/wiki/Apt#Quickstart
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt $CODENAME-pgdg main" |
  sudo tee -a /etc/apt/sources.list.d/pgdg.list

sudo apt update
sudo apt install --allow-downgrades -y \
  nginx brotli \
  build-essential libpcre3 libpcre3-dev zlib1g-dev

sudo DEBIAN_FRONTEND='noninteractive' \
  apt -y \
  -o Dpkg::Options::='--force-confdef' \
  -o Dpkg::Options::='--force-confold' \
  upgrade

sudo apt-get autoremove -y
sudo apt-get clean
sudo apt-get autoclean


sudo curl -o /etc/nginx/conf.d/00.nginx.http.conf https://blackcoffeecat.github.io/scripts/nginx.http.conf

curl -fsSL https://blackcoffeecat.github.io/scripts/upgrade-nginx.sh | bash -
sudo sed -i '7 a load_module modules/ngx_http_brotli_filter_module.so;' /etc/nginx/nginx.conf
sudo sed -i '7 a load_module modules/ngx_http_brotli_static_module.so;' /etc/nginx/nginx.conf


sudo nginx -t && sudo systemctl restart nginx || echo "debian-init: nginx config test fail."
sudo ufw disable || echo "no ufw"

echo -e "BLACKCOFFEECAT=1\n" | sudo tee -a /etc/environment
echo -e "NODE_ENV=production\n" | sudo tee -a /etc/environment


echo "debian-init: DONE!"
