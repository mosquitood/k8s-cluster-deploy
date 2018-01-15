#### Etcd集群
- k8s集群使用[etcd](https://coreos.com/etcd/)存储所有数据
- 本集群由三个etcd节点组成。
    1. etcd-node1 192.168.18.74
    2. etcd-node2 192.168.18.82
    3. etcd-node3 192.168.18.83

#### 环境变量

```
#当前部署的机器名称(随便定义，只要能区分不同机器即可)
NODE_NAME=etcd-node1

#当前部署的机器 IP
NODE_IP=192.168.18.74

#etcd 集群所有机器 IP
NODE_IPS=192.168.18.74 192.168.18.82 192.168.18.83

#etcd 集群服务地址列表
ETCD_ENDPOINTS=https://192.168.18.74:2379,https://192.168.18.82:2379,https://192.168.18.83:2379

#etcd 集群服务之间相互连接地址列表
ETCD_NODES=etcd-node1=https://192.168.18.74:2380,etcd-node2=https://192.168.18.82:2380,etcd-node3=https://192.168.18.83:2380
```

#### 命令安装

```
wget https://github.com/coreos/etcd/releases/download/v3.1.6/etcd-v3.1.6-linux-amd64.tar.gz

tar -xvf etcd-v3.1.6-linux-amd64.tar.gz

mv etcd-v3.1.6-linux-amd64/etcd* /usr/local/bin

rm -rf etcd-v3.1.6-linux-amd64*
```

#### 创建 TLS 秘钥和证书

```
cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
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

#### 生成 etcd 证书和私钥


```
cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=mosquitood-k8s etcd-csr.json | cfssljson -bare etcd

mkdir -p /etc/etcd/ssl

mv etcd*.pem /etc/etcd/ssl

rm -f etcd.csr  etcd-csr.json
```

#### 创建 etcd 的 systemd unit 文件

```
#必须先创建工作目录
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
ExecStart=/usr/local/bin/etcd \\
  --name=${NODE_NAME} \\
  --cert-file=/etc/etcd/ssl/etcd.pem \\
  --key-file=/etc/etcd/ssl/etcd-key.pem \\
  --peer-cert-file=/etc/etcd/ssl/etcd.pem \\
  --peer-key-file=/etc/etcd/ssl/etcd-key.pem \\
  --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --initial-advertise-peer-urls=https://${NODE_IP}:2380 \\
  --listen-peer-urls=https://${NODE_IP}:2380 \\
  --listen-client-urls=https://${NODE_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls=https://${NODE_IP}:2379 \\
  --initial-cluster-token=etcd-cluster \\
  --initial-cluster=${ETCD_NODES} \\
  --initial-cluster-state=new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

- 指定 etcd 的工作目录和数据目录为 /var/lib/etcd，需在启动服务前创建这个目录。
- 为了保证通信安全，需要指定 etcd 的公私钥(cert-file和key-file)、Peers 通信的公私钥和 CA 证书(peer-cert-file、peer-key-file、peer-trusted-ca-file)、客户端的CA证书（trusted-ca-file）。
- --initial-cluster-state 值为 new 时，--name 的参数值必须位于 --initial-cluster 列表中。

#### 启动etcd

```
mv etcd.service /etc/systemd/system/

systemctl daemon-reload

systemctl enable etcd

systemctl start etcd

#查看状态
systemctl status etcd
```
- 最先启动的 etcd 进程会卡住一段时间，等待其它节点上的 etcd 进程加入集群，为正常现象
- 在所有的 etcd 节点重复上面的步骤，直到所有机器的 etcd 服务都已启动。

#### 验证服务
在任一 etcd 集群节点上执行如下命令

```
for ip in ${NODE_IPS}; do
  ETCDCTL_API=3 /usr/local/bin/etcdctl \
  --endpoints=https://${ip}:2379  \
  --cacert=/etc/kubernetes/ssl/ca.pem \
  --cert=/etc/etcd/ssl/etcd.pem \
  --key=/etc/etcd/ssl/etcd-key.pem \
  endpoint health; done
```
预期结果（忽略warning）

```
2017-12-15 16:39:47.353994 I | warning: ignoring ServerName for user-provided CA for backwards compatibility is deprecated
https://192.168.18.74:2379 is healthy: successfully committed proposal: took = 2.242285ms
2017-12-15 16:39:47.400800 I | warning: ignoring ServerName for user-provided CA for backwards compatibility is deprecated
https://192.168.18.82:2379 is healthy: successfully committed proposal: took = 15.06205ms
2017-12-15 16:39:47.449708 I | warning: ignoring ServerName for user-provided CA for backwards compatibility is deprecated
https://192.168.18.83:2379 is healthy: successfully committed proposal: took = 3.281383ms
```





