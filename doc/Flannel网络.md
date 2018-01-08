#### Flannel 网络
- k8s 要求集群内各节点能通过 Pod 网段互联互通。
- Flannel 在所有节点 (Master、Node) 上创建互联互通的 Pod 网段。

#### 使用变量

```
#当前部署节点的 IP
NODE_IP=192.168.18.74

# etcd 集群服务地址列表
ETCD_ENDPOINTS="https://192.168.18.74:2379,https://192.168.18.82:2379,https://192.168.18.83:2379"

# flanneld 网络配置前缀
FLANNEL_ETCD_PREFIX="/kubernetes/network"

# POD 网段 (Cluster CIDR），部署前路由不可达，**部署后**路由可达 (flanneld 保证)
CLUSTER_CIDR="172.30.0.0/16"

```
#### 下载 flanneld

```
wget https://github.com/coreos/flannel/releases/download/v0.7.1/flannel-v0.7.1-linux-amd64.tar.gz

tar -xzvf flannel-v0.7.1-linux-amd64.tar.gz

mv flannel/{flanneld,mk-docker-opts.sh} /usr/local/bin
```

#### 创建 TLS 秘钥和证书
- etcd 集群启用了双向 TLS 认证，所以需要为 flanneld 指定与 etcd 集群通信的 CA 和秘钥。

##### 创建 flanneld 证书签名请求

```
cat > flanneld-csr.json <<EOF
{
  "CN": "flanneld",
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
##### 生成 flanneld 证书和私钥

```
cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=mosquitood-k8s flanneld-csr.json | cfssljson -bare flanneld
  
mkdir -p /etc/flanneld/ssl

mv flanneld*.pem /etc/flanneld/ssl

rm -f flanneld.csr  flanneld-csr.json
```

#### 向 etcd 写入集群 Pod 网段信息
- 注意，只需要写入一次即可


```
etcdctl \
  --endpoints=${ETCD_ENDPOINTS} \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/flanneld/ssl/flanneld.pem \
  --key-file=/etc/flanneld/ssl/flanneld-key.pem \
  set ${FLANNEL_ETCD_PREFIX}/config '{"Network":"'${CLUSTER_CIDR}'", "SubnetLen": 24, "Backend": {"Type": "vxlan"}}'
```

#### 创建 flanneld 的 systemd unit 文件

```
 cat > flanneld.service << EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
ExecStart=/usr/local/bin/flanneld \\
  -etcd-cafile=/etc/kubernetes/ssl/ca.pem \\
  -etcd-certfile=/etc/flanneld/ssl/flanneld.pem \\
  -etcd-keyfile=/etc/flanneld/ssl/flanneld-key.pem \\
  -etcd-endpoints=${ETCD_ENDPOINTS} \\
  -etcd-prefix=${FLANNEL_ETCD_PREFIX} \\
  -iface=ens33
ExecStartPost=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF
```

- mk-docker-opts.sh 脚本将分配给 flanneld 的 Pod 子网网段信息写入到 /run/flannel/docker 文件中，后续 docker 启动时使用这个文件中参数值设置 docker0 网桥。
- flanneld 使用系统缺省路由所在的接口和其它节点通信，对于有多个网络接口的机器（如，内网和公网），可以用 -iface 选项值指定通信接口(上面的 systemd unit 文件没指定这个选项)，如本着 Vagrant + Virtualbox，就要指定-iface=enp0s8。
- ifconfig 查看iface值(node节点真实ip对应的名称)

#### 启动 flanneld

```
mv flanneld.service /etc/systemd/system/

systemctl daemon-reload

systemctl enable flanneld

systemctl start flanneld

```

#### 检查flanneld 

```
ifconfig flannel.1
#逾期结果
flannel.1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1450
        inet 172.30.18.0  netmask 255.255.255.255  broadcast 0.0.0.0
        inet6 fe80::88f:80ff:fef6:b904  prefixlen 64  scopeid 0x20<link>
        ether 0a:8f:80:f6:b9:04  txqueuelen 0  (Ethernet)
        RX packets 35855  bytes 21768847 (20.7 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 37037  bytes 440717254 (420.3 MiB)
        TX errors 0  dropped 65 overruns 0  carrier 0  collisions 0

```

#### 检查分配给各 flanneld 的 Pod 网段信息

```
#查看集群 Pod 网段(/16)
/usr/local/bin/etcdctl \
  --endpoints=${ETCD_ENDPOINTS} \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/flanneld/ssl/flanneld.pem \
  --key-file=/etc/flanneld/ssl/flanneld-key.pem \
  get ${FLANNEL_ETCD_PREFIX}/config
# 查看已分配的 Pod 子网段列表(/24)
/usr/local/bin/etcdctl \
  --endpoints=${ETCD_ENDPOINTS} \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/flanneld/ssl/flanneld.pem \
  --key-file=/etc/flanneld/ssl/flanneld-key.pem \
  ls ${FLANNEL_ETCD_PREFIX}/subnets
# 查看某一 Pod 网段对应的 flanneld 进程监听的 IP 和网络参数
/usr/local/bin/etcdctl \
  --endpoints=${ETCD_ENDPOINTS} \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/flanneld/ssl/flanneld.pem \
  --key-file=/etc/flanneld/ssl/flanneld-key.pem \
  get ${FLANNEL_ETCD_PREFIX}/subnets/172.30.18.0-24

/usr/local/bin/etcdctl \
  --endpoints=${ETCD_ENDPOINTS} \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/flanneld/ssl/flanneld.pem \
  --key-file=/etc/flanneld/ssl/flanneld-key.pem \
  get ${FLANNEL_ETCD_PREFIX}/subnets/172.30.43.0-24

/usr/local/bin/etcdctl \
  --endpoints=${ETCD_ENDPOINTS} \
  --ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/flanneld/ssl/flanneld.pem \
  --key-file=/etc/flanneld/ssl/flanneld-key.pem \
  get ${FLANNEL_ETCD_PREFIX}/subnets/172.30.97.0-24

```

#### 检测是否通畅

- ifconfig命令，查看docker0(172.30.18.1)和flannel.1(172.30.18.0)的inet
- ping 网段网关，确保通畅。










