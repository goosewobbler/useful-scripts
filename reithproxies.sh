#!/bin/bash
 
#vars
proxy_host=www-cache.reith.bbc.co.uk
proxy_port=80
proxy_url=http://$proxy_host:$proxy_port
proxy_whitelist=localhost
socks_proxy_url=socks-gw.reith.bbc.co.uk:1085
sandbox_url=sandbox.bbc.co.uk
hosts_sandbox_rule="192.168.193.10    $sandbox_url"
hosts_current_sandbox_rule=$( grep "$sandbox_url" /etc/hosts | tail -1 )
gitproxy="#!/bin/sh\n# Use socat to proxy git through an HTTP CONNECT firewall.\n# Useful if you are trying to clone git:// from inside a company.\n# Requires that the proxy allows CONNECT to port 9418.\n#\n# Save this file as gitproxy somewhere in your path (e.g., ~/bin) and then run\n#   chmod +x gitproxy\n#   git config --global core.gitproxy gitproxy\n#\n# More details at http://tinyurl.com/8xvpny\n\n# Configuration. Common proxy ports are 3128, 8123, 8000.\n_proxy=$proxy_host\n_proxyport=$proxy_port\n\nexec socat STDIO PROXY:\$_proxy:\$1:\$2,proxyport=\$_proxyport"
 
if [ "$1" == "on" ]; then
  export http_proxy=$proxy_url
  export https_proxy=$proxy_url
  export ftp_proxy=$proxy_url
  export socks_proxy=$socks_proxy_url
  export no_proxy=$proxy_whitelist
  export SOCKS_PROXY=$socks_proxy_url
  export HTTP_PROXY=$proxy_url
  export HTTPS_PROXY=$proxy_url
  export FTP_PROXY=$proxy_url
  export NO_PROXY=$proxy_whitelist
  git config --global http.proxy $proxy_url
  git config --global https.proxy $proxy_url
  npm config set proxy $proxy_url
  npm config set http-proxy $proxy_url
  npm config set https-proxy $proxy_url
  hash gitproxy 2>/dev/null || {
    echo -e $gitproxy | sudo tee /usr/local/bin/gitproxy > /dev/null
    sudo chmod 777 /usr/local/bin/gitproxy
  }
  git config --global core.gitproxy gitproxy
  if [ "$hosts_current_sandbox_rule" != "" ]; then
    sudo sed -i '' "/$sandbox_url/d" /etc/hosts
  fi
  echo "reith proxies enabled"
elif [ "$1" == "off" ]; then
  unset -v http_proxy
  unset -v https_proxy
  unset -v ftp_proxy
  unset -v socks_proxy
  unset -v no_proxy
  unset -v HTTP_PROXY
  unset -v HTTPS_PROXY
  unset -v FTP_PROXY
  unset -v SOCKS_PROXY
  unset -v NO_PROXY
  git config --global --unset http.proxy
  git config --global --unset https.proxy
  git config --global --unset core.gitproxy
  if [ $(npm config get proxy) != "null" ]; then
    npm config delete proxy
  fi
  if [ $(npm config get https-proxy) != "null" ]; then
    npm config delete https-proxy
  fi
  if [ "$hosts_current_sandbox_rule" == "" ]; then
    echo "$hosts_sandbox_rule" | sudo tee -a /etc/hosts > /dev/null
  fi
  echo "reith proxies disabled"
else
  if [ "$http_proxy" == "$proxy_url" ]; then
    echo "reith proxies are currently enabled"
  else
    echo "reith proxies are currently disabled"
  fi
fi
 
dscacheutil -flushcache