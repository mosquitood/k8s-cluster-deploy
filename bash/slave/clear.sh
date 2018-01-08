#!/bin/sh
systemctl stop kubelet kube-proxy flanneld docker
rm -rf /var/lib/kubelet
rm -rf /var/lib/docker
rm -rf /var/run/flannel/
rm -rf /var/run/docker/
rm -rf /etc/systemd/system/{kubelet,docker,flanneld}.service
rm -rf /root/local/bin/{kubelet,docker,flanneld}
rm -rf /etc/flanneld/ssl /etc/kubernetes/ssl
iptables -F && sudo iptables -X && sudo iptables -F -t nat && sudo iptables -X -t nat
ip link del flannel.1
ip link del docker0
