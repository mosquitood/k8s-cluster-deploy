#### kubectl命令行工具
- kubectl 默认从 ~/.kube/config 配置文件获取访问 kube-apiserver 地址、证书、用户名等信息。
- master节点部署

#### 使用变量

```
#替换为 kubernetes master 集群任一机器 IP
MASTER_IP=192.168.18.74

#变量 KUBE_APISERVER 指定 kubelet 访问的 kube-apiserver 的地址，后续被写入 ~/.kube/config 配置文件
KUBE_APISERVER="https://${MASTER_IP}:6443"
```

#### 下载kubectl工具

```
wget https://dl.k8s.io/v1.8.4/kubernetes-client-linux-amd64.tar.gz

tar -xzvf kubernetes-client-linux-amd64.tar.gz

cp kubernetes/client/bin/kube* /usr/local/bin/

chmod a+x /usr/local/bin/kube*
```

#### 创建 admin 证书
- kubectl 与 kube-apiserver 的安全端口通信，需要为安全通信提供 TLS 证书和秘钥。

##### 创建 admin 证书签名请求

```
cat admin-csr.json
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
```

- 后续 kube-apiserver 使用 RBAC 对客户端(如 kubelet、kube-proxy、Pod)请求进行授权。
- kube-apiserver 预定义了一些 RBAC 使用的 RoleBindings，如 cluster-admin 将 Group system:masters 与 Role cluster-admin 绑定，该 Role 授予了调用kube-apiserver 所有 API的权限。
- O 指定该证书的 Group 为 system:masters，kubelet 使用该证书访问 kube-apiserver 时 ，由于证书被 CA 签名，所以认证通过，同时由于证书用户组为经过预授权的 system:masters，所以被授予访问所有 API 的权限。

##### 生成 admin 证书和私钥

```
cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=mosquitood-k8s admin-csr.json | cfssljson -bare admin
  
mv admin*.pem /etc/kubernetes/ssl/
rm -f admin.csr admin-csr.json
```

#### 创建 kubectl kubeconfig 文件

```
#设置集群参数

kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER}
  
#设置客户端认证参数

kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/ssl/admin.pem \
  --embed-certs=true \
  --client-key=/etc/kubernetes/ssl/admin-key.pem
  
#设置上下文参数

kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin
  
#设置默认上下文

kubectl config use-context kubernetes
```
- 生成的 kubeconfig 被保存到 ~/.kube/config 文件。

#### 分发 kubeconfig 文件
- 将 ~/.kube/config 文件拷贝到运行 kubelet（k8s集群slave节点） 命令的机器的 ~/.kube/ 目录下。




