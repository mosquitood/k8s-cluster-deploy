#!/bin/sh

#关闭防火墙
systemctl stop firewalld && systemctl disable firewalld

#关闭selinux
setenforce 0

#打开forward
sysctl -w net.ipv4.ip_forward=1

#关闭swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

yum install -y ebtables socat
sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
sysctl net.bridge.bridge-nf-call-arptables=1
cat > /etc/sysctl.d/k8s.conf <<EOF 
net.bridge.bridge-nf-call-ip6tables=1 
net.bridge.bridge-nf-call-iptables=1 
net.bridge.bridge-nf-call-arptables=1
EOF 
sysctl –system
