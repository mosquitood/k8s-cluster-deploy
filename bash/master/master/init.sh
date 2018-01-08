#!/bin/sh
pushd ${k8s_dir}/master

rm -f /usr/local/bin/kube*
cp -r ./bin/server/{kube-apiserver,kube-controller-manager,kube-scheduler,kubectl,kube-proxy,kubelet} /usr/local/bin/

cat > k8s-master-csr.json <<EOF
{
  "CN": "k8s-master",
  "hosts": [
    "127.0.0.1",
    "${MASTER_IP}",
    "${CLUSTER_KUBERNETES_SVC_IP}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
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
  -profile=mosquitood-k8s k8s-master-csr.json | cfssljson -bare k8s-master 

mkdir -p /etc/kubernetes/ssl/
mv k8s-master*.pem /etc/kubernetes/ssl/
rm -f k8s* 

cat > token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
mv token.csv /etc/kubernetes/

rm -f *.service
cat  > kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
  --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
  --advertise-address=${MASTER_IP} \
  --bind-address=${MASTER_IP} \
  --insecure-bind-address=${MASTER_IP} \
  --authorization-mode=RBAC \
  --runtime-config=rbac.authorization.k8s.io/v1alpha1 \
  --kubelet-https=true \
  --experimental-bootstrap-token-auth \
  --token-auth-file=/etc/kubernetes/token.csv \
  --service-cluster-ip-range=${SERVICE_CIDR} \
  --service-node-port-range=${NODE_PORT_RANGE} \
  --tls-cert-file=/etc/kubernetes/ssl/k8s-master.pem \
  --tls-private-key-file=/etc/kubernetes/ssl/k8s-master-key.pem \
  --client-ca-file=/etc/kubernetes/ssl/ca.pem \
  --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem \
  --etcd-cafile=/etc/kubernetes/ssl/ca.pem \
  --etcd-certfile=/etc/kubernetes/ssl/k8s-master.pem \
  --etcd-keyfile=/etc/kubernetes/ssl/k8s-master-key.pem \
  --etcd-servers=${ETCD_ENDPOINTS} \
  --enable-swagger-ui=true \
  --allow-privileged=true \
  --apiserver-count=3 \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/var/lib/audit.log \
  --event-ttl=1h \
  --v=2
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl stop kube-apiserver
rm -f /etc/systemd/system/kube-apiserver.service
cp kube-apiserver.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable kube-apiserver
systemctl start kube-apiserver


 cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \
  --address=127.0.0.1 \
  --master=http://${MASTER_IP}:8080 \
  --allocate-node-cidrs=true \
  --service-cluster-ip-range=${SERVICE_CIDR} \
  --cluster-cidr=${CLUSTER_CIDR} \
  --cluster-name=kubernetes \
  --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem \
  --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem \
  --service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem \
  --root-ca-file=/etc/kubernetes/ssl/ca.pem \
  --leader-elect=true \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl stop kube-controller-manager
rm -f /etc/systemd/system/kube-controller-manager.service
cp kube-controller-manager.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl start kube-controller-manager



cat > kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \
  --address=127.0.0.1 \
  --master=http://${MASTER_IP}:8080 \
  --leader-elect=true \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cp kube-scheduler.service /etc/systemd/system/

systemctl stop kube-scheduler
rm -f *.service

systemctl daemon-reload
systemctl enable kube-scheduler
systemctl start kube-scheduler
