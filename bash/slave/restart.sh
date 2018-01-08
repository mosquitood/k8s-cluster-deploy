#!/bin/sh
systemctl daemon-reload
systemctl restart flanneld.service 
systemctl restart docker.service  
systemctl restart kubelet.service 
systemctl restart kube-proxy.service 
