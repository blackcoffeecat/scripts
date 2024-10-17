#!/usr/bin/env bash

fulldomain=$1
address=$2
CF_Token="${3-$CF_Token}"
type="A"

CF_Api="https://api.cloudflare.com/client/v4"

if [[ address =~ '^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$' ]]; then
  type = "AAAA";
fi

record="{\"name\": \"$fulldomain\",\"type\": \"$type\",\"content\": \"$address\",\"ttl\": 1,\"proxied\": false}"

_zone_id=""
_CURL="curl -SsL --user-agent cfdns"

if [ "$(echo abc | egrep -o b 2>/dev/null)" = "b" ]; then
  __USE_EGREP=1
else
  __USE_EGREP=""
fi

_egrep_o() {
  if [ "$__USE_EGREP" ]; then
    egrep -o -- "$1" 2>/dev/null
  else
    sed -n 's/.*\('"$1"'\).*/\1/p'
  fi
}

_contains() {
  _str="$1"
  _sub="$2"
  echo "$_str" | grep -- "$_sub" >/dev/null 2>&1
}

_math() {
  _m_opts="$@"
  printf "%s" "$(($_m_opts))"
}

_post() {
  body="$1"
  _post_url="$2"
  needbase64="$3"
  httpmethod="$4"
  _postContentType="$5"

  if [ -z "$httpmethod" ]; then
    httpmethod="POST"
  fi
  if [ "$httpmethod" = "HEAD" ]; then
    _CURL="$_CURL -I  "
  fi
 
  if [ "$body" ]; then
    response="$($_CURL -X $httpmethod -H \"Content-Type: application/json\" -H \"Authorization: Bearer $(echo "$CF_Token" | tr -d '"')\" --data "$body" "$_post_url")"
  else
    response="$($_CURL -X $httpmethod -H \"Authorization: Bearer $(echo "$CF_Token" | tr -d '"')\" "$_post_url")"
  fi
  
  _ret="$?"
  printf "%s" "$response"
  return $_ret
}

_get() {
  url="$1"
  t="$3"

  $_CURL -H \"Authorization: Bearer $(echo "$CF_Token" | tr -d '"')\"  "$url"
  ret=$?
  return $ret
}

_cf_rest() {
  m=$1
  ep="$2"
  data="$3"
  if [ "$m" != "GET" ]; then
    response="$(_post "$data" "$CF_Api/$ep" "" "$m")"
  else
    response="$(_get "$CF_Api/$ep")"
  fi

  if [ "$?" != "0" ]; then
    return 1
  fi
  return 0
}

_get_root() {
  domain=$1
  i=1
  p=1

  while true; do
    h=$(printf "%s" "$domain" | cut -d . -f "$i"-100)
    if [ -z "$h" ]; then
      return 1
    fi

    if ! _cf_rest GET "zones?name=$h"; then
      return 1
    fi

    if _contains "$response" "\"name\":\"$h\"" || _contains "$response" '"total_count":1'; then
      _zone_id=$(echo "$response" | _egrep_o "\[.\"id\": *\"[^\"]*\"" | head -n 1 | cut -d : -f 2 | tr -d \" | tr -d " ")
      if [ "$_zone_id" ]; then
        _sub_domain=$(printf "%s" "$domain" | cut -d . -f 1-"$p")
        _domain=$h
        return 0
      fi
      return 1
    fi
    p=$i
    i=$(_math "$i" + 1)
  done
  return 1
}

if ! _get_root "$fulldomain"; then
  _err "invalid domain"
  return 1
fi

_cf_rest GET "zones/$_zone_id/dns_records?type=$type&name=$fulldomain"

if _contains "$response" "\"name\":\"$h\"" || _contains "$response" '"total_count":1'; then
  _record_id=$(echo "$response" | _egrep_o "\[.\"id\": *\"[^\"]*\"" | head -n 1 | cut -d : -f 2 | tr -d \" | tr -d " ")
  _cf_rest PUT "zones/$_zone_id/dns_records/$_record_id" "$record"
else
  _cf_rest POST "zones/$_zone_id/dns_records" "$record"
fi
