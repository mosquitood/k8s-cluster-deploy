# Calico 网络

- k8s 要求集群内各节点能通过 Pod 网段互联互通。
- Calico 在所有节点 (Master、Node) 上创建互联互通的 Pod 网段。

### 使用变量

```shell
# etcd 集群服务地址列表
ETCD_ENDPOINTS="https://192.168.18.74:2379,https://192.168.18.82:2379,https://192.168.18.83:2379"
#节点名称 必须保证与当前宿主机的名称一致
NODE_NAME="k8s-master"
```

#### 创建 TLS 秘钥和证书

- etcd 集群启用了双向 TLS 认证，所以需要为 calico 指定与 etcd 集群通信的 CA 和秘钥

##### 创建 calico证书签名请求

```shell
cat > calico-node-csr.json <<EOF
{
  "CN": "calico-node",
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
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
```

##### 生成 calico证书和私钥

```shell
cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=mosquitood-k8s calico-node-csr.json | cfssljson -bare calico-node

mkdir -p /etc/calico-node/ssl
mv calico-node*.pem /etc/calico-node/ssl
rm -f calico*
```

### 安装 calico/node

###### 创建system unit文件

- 需要启动docker

```shell
mkdir -p /var/run/calico
mkdir -p /lib/modules
mkdir -p /var/log/calico

cat > calico-node.service << EOF
[Unit]
Description=calico node
After=etcd.service
After=docker.service
Requires=docker.service

[Service]
User=root
PermissionsStartOnly=true
ExecStart=/usr/bin/docker run --net=host --privileged --name=${NODE_NAME} \
  -e CALICO_ETCD_ENDPOINTS=${ETCD_ENDPOINTS} \
  -e CALICO_ETCD_CA_CERT_FILE=/etc/kubernetes/ssl/ca.pem \
  -e CALICO_ETCD_CERT_FILE=/etc/calico-node/ssl/calico-node.pem \
  -e CALICO_ETCD_KEY_FILE=/etc/calico-node/ssl/calico-node-key.pem \
  -e WAIT_FOR_DATASTORE=true \
  -e NODENAME=${NODE_NAME} \
  -e CLUSTER_TYPE=k8s \
  -e CALICO_NETWORKING_BACKEND=bird \
  -e FELIX_DEFAULTENDPOINTTOHOSTACTION=ACCEPT \
  -v /var/run/calico:/var/run/calico \
  -v /lib/modules:/lib/modules \
  -v /run/docker/plugins:/run/docker/plugins \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/log/calico:/var/log/calico \
	-v /etc/kubernetes/ssl/ca.pem:/etc/kubernetes/ssl/ca.pem \
	-v /etc/calico-node/ssl/calico-node.pem:/etc/calico-node/ssl/calico-node.pem \
	-v /etc/calico-node/ssl/calico-node-key.pem:/etc/calico-node/ssl/calico-node-key.pem \
  quay.io/calico/node:v3.0.1
ExecStop=/usr/bin/docker rm -f ${NODE_NAME} 
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

rm -f /etc/systemd/system/calico-node.service
cp calico-node.service /etc/systemd/system/
rm -f calico-node.service
systemctl daemon-reload
systemctl enable calico-node
systemctl start calico-node
```

- NODE_NAME变量必须和本机的hostname一致
- 如果使用了TLS，必须将cert和key挂载到容器中。否则连接etcd超时
- CLUSTER_TYPE设置为k8s，因为当前是在k8s集群中使用

### 安装CNI插件

#### 下载并安装CNI插件

```shell
wget -N -P /opt/cni/bin https://github.com/projectcalico/cni-plugin/releases/download/v2.0.0/calico
wget -N -P /opt/cni/bin https://github.com/projectcalico/cni-plugin/releases/download/v2.0.0/calico-ipam
chmod +x /opt/cni/bin/calico /opt/cni/bin/calico-ipam
```

#### 创建CNI配置文件

cat >/etc/cni/net.d/10-calico.conf <<EOF
{

```
"name": "${NODE_NAME}",
"cniVersion": "0.1.0",
"type": "calico",
"etcd_endpoints": "${ETCD_ENDPOINTS}",
	"etcd_ca_cert_file": "/etc/kubernetes/ssl/ca.pem",
	"etcd_cert_file": "/etc/calico-node/ssl/calico-node.pem",
	"etcd_key_file": "/etc/calico-node/ssl/calico-node-key.pem",
"log_level": "info",
"ipam": {
    "type": "calico-ipam"
},
"policy": {
    "type": "k8s"
},
"kubernetes": {
    "kubeconfig": "~/.kube/config"
}
```

}
EOF

```shell
cat >/etc/cni/net.d/10-calico.conf <<EOF
{
    "name": "${NODE_NAME}",
    "cniVersion": "0.1.0",
    "type": "calico",
    "etcd_endpoints": "${ETCD_ENDPOINTS}",
		"etcd_ca_cert_file": "/etc/kubernetes/ssl/ca.pem",
		"etcd_cert_file": "/etc/calico-node/ssl/calico-node.pem",
		"etcd_key_file": "/etc/calico-node/ssl/calico-node-key.pem",
    "log_level": "info",
    "ipam": {
        "type": "calico-ipam"
    },
    "policy": {
        "type": "k8s"
    },
    "kubernetes": {
        "kubeconfig": "$HOME/.kube/config"
    }
}
EOF
```

- name字段必须是宿主机的名称。
- etcd_endpoints 及证书要配置下。
- policy：type设置为k8s。
- kubernetes:  kubeconfig为了访问kube-apiserver。绝对路径啊。

#### 标准CNI lo 插件安装

```shell
wget https://github.com/containernetworking/cni/releases/download/v0.3.0/cni-v0.3.0.tgz
tar -zxvf cni-v0.3.0.tgz
sudo cp loopback /opt/cni/bin/
```



### 安装Calico Kubernetes controllers (只在master节点)

```shell
cat > calico-rbac.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: calico-kube-controllers 
  namespace: kube-system
---

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: calico-kube-controllers
rules:
  - apiGroups:
    - ""
    - extensions
    resources:
      - pods
      - namespaces
      - networkpolicies
      - nodes
    verbs:
      - watch
      - list
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: calico-kube-controllers
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: calico-kube-controllers
subjects:
- kind: ServiceAccount
  name: calico-kube-controllers
  namespace: kube-system

---

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: calico-node
rules:
  - apiGroups: [""]
    resources:
      - pods
      - nodes
    verbs:
      - get

---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: calico-node
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: calico-node
subjects:
- kind: ServiceAccount
  name: calico-node
  namespace: kube-system
EOF
```

- rbac 权限控制。

```shell
cat > calico-kube-controllers.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: calico-kube-controllers
  namespace: kube-system
  labels:
    k8s-app: calico-kube-controllers
spec:
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      name: calico-kube-controllers
      namespace: kube-system
      labels:
        k8s-app: calico-kube-controllers
    spec:
      hostNetwork: true
      serviceAccountName: calico-kube-controllers
      containers:
        - name: calico-kube-controllers
          image: quay.io/calico/kube-controllers:v2.0.0
          env:
          - name: ETCD_ENDPOINTS
            value: "https://192.168.18.164:2379"
          - name: ETCD_CA_CERT_FILE
            value: "/etc/kubernetes/ssl/ca.pem"
          - name: ETCD_CERT_FILE
            value: "/etc/calico-node/ssl/calico-node.pem"
          - name: ETCD_KEY_FILE
            value: "/etc/calico-node/ssl/calico-node-key.pem"
          - name: ENABLED_CONTROLLERS
            value: "policy,profile,workloadendpoint,node"
          - name: LOG_LEVEL
            value: "debug"
          - name: KUBECONFIG
            value: "/root/.kube/config"
          volumeMounts:
          - name: ca 
            mountPath: /etc/kubernetes/ssl/ca.pem
          - name: cert 
            mountPath: /etc/calico-node/ssl/calico-node.pem
          - name: key 
            mountPath: /etc/calico-node/ssl/calico-node-key.pem
          - name: kubeconfig 
            mountPath: /root/.kube/config 
      volumes:
      - name: ca 
        hostPath: 
          path: /etc/kubernetes/ssl/ca.pem
          type: File
      - name: cert 
        hostPath: 
          path: /etc/calico-node/ssl/calico-node.pem
          type: File
      - name: key 
        hostPath: 
          path: /etc/calico-node/ssl/calico-node-key.pem
          type: File
      - name: kubeconfig 
        hostPath: 
          path: /root/.kube/config
          type: File
EOF
kubectl create -f calico-rbac.yaml 
kubectl create -f calico-kube-controllers.yaml
```

- deployment 文件。
- 各类证书必须挂载到容器中。否则连不上etcd。
- kubeconfig和证书一样。

