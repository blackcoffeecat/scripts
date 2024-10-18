# scripts

## Usage

```shell
# set debian-init.sh as startup script

if [ "$BLACKCOFFEECAT" != "1" ]
then 
  curl -sSL https://blackcoffeecat.github.io/scripts/debian-init.sh | nohup bash - > /var/log/debian-init.log 2>&1 &
fi
```
