iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i zt+ -o eth0 -s <IP-DA-SUBREDE> -p tcp -m multiport --dports 22,443,8006 -j ACCEPT
iptables -A FORWARD -i zt+ -o eth0 -p icmp -j ACCEPT
iptables -A FORWARD -i eth0 -o zt+ -m state --state RELATED,ESTABLISHED -j ACCEPT
netfilter-persistent save