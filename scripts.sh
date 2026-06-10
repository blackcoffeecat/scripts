

# 生成自签名证书
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout ./ssl.key \
  -out ./ssl.crt
