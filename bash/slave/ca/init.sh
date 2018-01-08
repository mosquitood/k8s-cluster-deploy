#!/bin/sh
pushd ${k8s_dir}/ca
rm -f /usr/local/bin/cfssl*

chmod +x ./bin/cfssl_linux-amd64
cp ./bin/cfssl_linux-amd64 /usr/local/bin/cfssl

chmod +x ./bin/cfssljson_linux-amd64
cp ./bin/cfssljson_linux-amd64 /usr/local/bin/cfssljson

chmod +x ./bin/cfssl-certinfo_linux-amd64
cp ./bin/cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo

export PATH=/usr/local/bin:$PATH
popd
