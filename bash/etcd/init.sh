#!/bin/sh
. ./env.sh

rm -f /usr/local/bin/etcd*
cp ./bin/* /usr/local/bin/

cat > etcd-csr.json <<EOF
{
  "CN": "mosquitood-etcd",
  "hosts": [
    "127.0.0.1",
    "${NODE_IP}"
  ],
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

cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=mosquitood-k8s etcd-csr.json | cfssljson -bare etcd

mkdir -p /etc/etcd/ssl
rm -f /etc/etcd/ssl/*
cp etcd*.pem /etc/etcd/ssl

mkdir -p /var/lib/etcd


cat > etcd.service <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/local/bin/etcd \
  --name=${NODE_NAME} \
  --cert-file=/etc/etcd/ssl/etcd.pem \
  --key-file=/etc/etcd/ssl/etcd-key.pem \
  --peer-cert-file=/etc/etcd/ssl/etcd.pem \
  --peer-key-file=/etc/etcd/ssl/etcd-key.pem \
  --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
  --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
  --initial-advertise-peer-urls=https://${NODE_IP}:2380 \
  --listen-peer-urls=https://${NODE_IP}:2380 \
  --listen-client-urls=https://${NODE_IP}:2379,https://127.0.0.1:2379 \
  --advertise-client-urls=https://${NODE_IP}:2379 \
  --initial-cluster-token=etcd-cluster \
  --initial-cluster=${ETCD_NODES} \
  --initial-cluster-state=new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

rm -f /etc/systemd/system/etcd.service
cp etcd.service /etc/systemd/system/
rm -f etcd*
systemctl stop firewalld.service
systemctl disable firewalld.service
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
systemctl status etcd

