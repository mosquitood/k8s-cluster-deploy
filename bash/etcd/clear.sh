#!/bin/sh
systemctl stop etcd
rm -rf /var/lib/etcd
rm -rf /etc/systemd/system/etcd.service
rm -rf /root/local/bin/etcd
rm -rf /etc/etcd/ssl/*
