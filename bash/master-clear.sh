#!/bin/sh
systemctl stop kube-apiserver kube-controller-manager kube-scheduler
rm -rf /var/run/kubernetes
rm -rf /etc/systemd/system/{kube-apiserver,kube-controller-manager,kube-scheduler}.service
rm -rf /root/local/bin/{kube-apiserver,kube-controller-manager,kube-scheduler}
rm -rf /etc/flanneld/ssl /etc/kubernetes/ssl
