#!/bin/sh
rm -f /usr/local/bin/cfssl*

chmod +x ./bin/cfssl_linux-amd64
cp ./bin/cfssl_linux-amd64 /usr/local/bin/cfssl

chmod +x ./bin/cfssljson_linux-amd64
cp ./bin/cfssljson_linux-amd64 /usr/local/bin/cfssljson

chmod +x ./bin/cfssl-certinfo_linux-amd64
cp ./bin/cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo

export PATH=/usr/local/bin:$PATH
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "mosquitood-k8s": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "mosquitood-k8s",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "TianJin",
      "L": "TianJin",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
rm -rf /etc/kubernetes/ssl
mkdir -p /etc/kubernetes/ssl
cp ca* /etc/kubernetes/ssl
rm -f ca*
