#!/bin/sh
systemctl daemon-reload
systemctl restart flanneld.service 
systemctl restart kube-apiserver.service 
systemctl restart kube-controller-manager.service 
systemctl restart kube-scheduler.service
