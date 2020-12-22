#!/usr/bin/env bash

gen(){
    clients=1
    path=1024.html
    echo "["
while read n r s p t w; do
    echo '  {
    "scheme": "https",
    "tls-session-reuse": true,
    "host": "'${r}'",
    "port": 443,
    "method": "GET",
    "path": "'${path}'",
    "delay": {
      "min": 0,
      "max":0 
    },
    "keep-alive-requests": 1,
    "clients": '${clients}'
  },'
done <<< $(oc get route -n http-perf --no-headers)
    echo "]"
}
