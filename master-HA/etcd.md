# 本文档构建高可用etcd集群

本集群有三个节点组成，IP地址为192.168.18.223，192.168.18.225，192.168.18.226。

- etcd节点使用静态pod
- 静态pod的高可用由kubelet保证
- kubelet的高可用由systemctl保证
- 为保证安全,使用TLS

## 变量

```sh
NODE_NAME=etcd-node1
NODE_IP=192.168.18.223
```

## CA和秘钥

- <a href="/doc/CA和秘钥.md">参照文档CA和秘钥</a>
- 证书生成只需在某个节点生成，然后分发到集群节点。

## docker安装

```
#版本
Version:      17.03.0-ce
API version:  1.26
Go version:   go1.7.5
 
#删除残留的docker
yum remove docker \
                  docker-common \
                  docker-selinux \
                  docker-engine
#下载docker
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.03.0.ce-1.el7.centos.x86_64.rpm

#下载docker-ce-selinux

wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-selinux-17.03.0.ce-1.el7.centos.noarch.rpm

#安装selinux 
yum -y install docker-ce-selinux-17.03.0.ce-1.el7.centos.noarch.rpm
#安装docker
yum -y install docker-ce-17.03.0.ce-1.el7.centos.x86_64.rpm
#开机自启动
systemctl enable docker
systemctl start docker
```

- 集群所有节点都要安装docker

## etcd证书

### 创建TLS秘钥和证书

```
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
```

- hosts 字段指定授权使用该证书的 etcd 节点 IP。
- NODE_IP指的是当前节点IP。

### 生成etcd证书和私钥

```
cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=mosquitood-k8s etcd-csr.json | cfssljson -bare etcd

mkdir -p /etc/etcd/ssl

mv etcd*.pem /etc/etcd/ssl

rm -f etcd.csr  etcd-csr.json
```

- 集群所有节点都要生成证书

### 静态pod配置文件

```Shell
cat > etcd.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: etcd-cluster
spec:
  hostNetwork: true #使用主机网络，网络通信不通过docker网桥
  containers:
  - image: mosquitood/docker-etcd:3.1.6
    name: etcd-container
    command:
    - /bin/etcd
    - --name=${NODE_ANME}
    - --initial-advertise-peer-urls=https://${NODE_IP}:2380
    - --listen-peer-urls=https://${NODE_IP}:2380
    - --listen-client-urls=https://${NODE_IP}:2379,http://127.0.0.1:2379   
    - --advertise-client-urls=https://${NODE_IP}:2379   
    - --data-dir=/var/etcd/data
    - --discovery=https://discovery.etcd.io/7ea3025baf93f7915c33787be8f83766
    - --cert-file=/etc/etcd/ssl/etcd.pem
    - --key-file=/etc/etcd/ssl/etcd-key.pem
    - --trusted-ca-file=/etc/ca/ssl/ca.pem 
    - --peer-cert-file=/etc/etcd/ssl/etcd.pem
    - --peer-key-file=/etc/etcd/ssl/etcd-key.pem
    - --peer-trusted-ca-file=/etc/ca/ssl/ca.pem
    ports:
    - name: serverport
      containerPort: 2380
      hostPort: 2380
    - name: clientport
      containerPort: 2379 
      hostPort: 2379 
    volumeMounts:
    - mountPath: /var/etcd/data
      name: varetcd
    - mountPath: /etc/etcd/ssl
      name: etcdssl
      readOnly: true
    - mountPath: /etc/ca/ssl
      name: cassl
      readOnly: true
  volumes:
  - hostPath:
      path: /var/etcd/data
    name: varetcd
  - hostPath:
      path: /etc/etcd/ssl
    name: etcdssl
  - hostPath:
      path: /etc/kubernetes/ssl
    name: cassl
EOF

mkdir -p /etc/kubernetes/manifests
cp etcd.yaml /etc/kubernetes/manifests/etcd.yaml
```
- discovery参数有命令 curl https://discovery.etcd.io/new?size=3 生成
- NODE_NAME 集群当前节点名称，不能重复。
- NODE_IP 集群当前节点IP。

## 安装kubelet

- etcd pod由kubelet启动并管理，如果pod挂掉或者yaml文件有更改，kubelet都会重新启动pod，保证高可用。
- 静态pod不受kube-apiserver控制
- 安装kubelet命令行工具以前文档有详细说明，不再多说。
- 关闭swap。
- Systemd 保证kubelet高可用。

#### systemd unit

```Shell
mkdir -p /var/lib/kubelet
cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=/usr/local/bin/kubelet --address=${NODE_IP} --hostname-override=${NODE_NAME} --pod-infra-container-image=mosquitood/k8s-rhel7-pod-infrastructure:3.6 --cert-dir=/etc/kubernetes/ssl --hairpin-mode promiscuous-bridge --allow-privileged=true --serialize-image-pulls=true --logtostderr=true --v=2  --pod-manifest-path=/etc/kubernetes/manifests/
ExecStartPost=/sbin/iptables -A INPUT -s 10.0.0.0/8 -p tcp --dport 4194 -j ACCEPT
ExecStartPost=/sbin/iptables -A INPUT -s 172.16.0.0/12 -p tcp --dport 4194 -j ACCEPT
ExecStartPost=/sbin/iptables -A INPUT -s 192.168.0.0/16 -p tcp --dport 4194 -j ACCEPT
ExecStartPost=/sbin/iptables -A INPUT -p tcp --dport 4194 -j DROP
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
cp kubelet.service /etc/systemd/system/kubelet.service
systemctl enable kubelet
systemctl start kubelet
```
- NODE_NAME 集群当前节点名称，不能重复。
- NODE_IP 集群当前节点IP。
## 检查

```shell
#docker
systemctl status docker -l
#kubelet
systemctl status kubelet -l
#etcd pod 
docker ps -a

#检测集群健康情况
export ETCDCTL_API=3
etcdctl --endpoints=https://192.168.18.223:2379 \
  --cacert=/etc/kubernetes/ssl/ca.pem \
  --cert=/etc/etcd/ssl/etcd.pem \
  --key=/etc/etcd/ssl/etcd-key.pem \
  endpoint health 

etcdctl --endpoints=https://192.168.18.225:2379 \
  --cacert=/etc/kubernetes/ssl/ca.pem \
  --cert=/etc/etcd/ssl/etcd.pem \
  --key=/etc/etcd/ssl/etcd-key.pem \
  endpoint health 

etcdctl --endpoints=https://192.168.18.226:2379 \
  --cacert=/etc/kubernetes/ssl/ca.pem \
  --cert=/etc/etcd/ssl/etcd.pem \
  --key=/etc/etcd/ssl/etcd-key.pem \
  endpoint health
```
- 集群健康检测要在集群部署完成后检测。
- 如果没有etcdctl命令，安装即可。

## 参考文档
- <a href="https://kubernetes.io/docs/admin/high-availability/">Building High-Availability Clusters</a>
- <a href="https://coreos.com/etcd/docs/latest/">Etcd Document</a>
