# Usage example:
# clear_firewall
# init_forwarding 192.168.122.0/24
# forward_port 123 foo 456    # source-port  dest-host  dest-port

gethost() {
  getent hosts $1 | awk '{ print $1 }'
}

# Usage: forward_port source-port dest-host dest-port
forward_port() {
  SOURCE_PORT="$1"
  DEST_IP=`gethost "$2"`
  DEST_PORT="$3"

  iptables -t nat -A PREROUTING -p tcp --dport $SOURCE_PORT -j DNAT --to $DEST_IP:$DEST_PORT
  iptables -A FORWARD -p tcp -d $DEST_IP --dport $DEST_PORT -j ACCEPT
}

clear_firewall() {
  iptables -F
  iptables -t nat -F
  echo 0 > /proc/sys/net/ipv4/ip_forward
}

# Takes subnet as parameter
init_forwarding() {
  SUBNET="$1"
  echo 1 > /proc/sys/net/ipv4/ip_forward
  iptables -t nat -A POSTROUTING -s $SUBNET -j MASQUERADE
}
