# This script is a simple function to update the SSH known_hosts file before connecting to the specified server.
# For use when you want to connect to a server whose key fingerprint has recently changed.
# ---
# Usage: 
# 
# ssh-update blah@127.0.0.1
# ---
# Currently only supports IPV4 addresses

removeKnownHostAndConnect() {
  regex="([0-9]{1,3}[\.]){3}[0-9]{1,3}"
  if [[ $@ =~ $regex ]]; then
    ssh-keygen -R $BASH_REMATCH
    ssh $@
  fi
}

alias ssh-update-host="removeKnownHostAndConnect $@"
