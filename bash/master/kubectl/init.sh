#!/bin/sh
pushd ${k8s_dir}/kubectl
cp ./bin/* /usr/local/bin/

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "TianJin",
      "L": "TianJin",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=mosquitood-k8s admin-csr.json | cfssljson -bare admin
mv admin*.pem /etc/kubernetes/ssl/
rm -f admin*

# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER}

# 设置客户端认证参数
kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/ssl/admin.pem \
  --embed-certs=true \
  --client-key=/etc/kubernetes/ssl/admin-key.pem

 # 设置上下文参数
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin

 # 设置默认上下文
kubectl config use-context kubernetes  

popd
