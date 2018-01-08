#!/bin/sh
pushd ${k8s_dir}/kubectl
rm -f /usr/local/bin/kubectl 
rm -f /usr/local/bin/kubefed

cp ./bin/* /usr/local/bin/

kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap

popd
