#### CA证书和秘钥
为保证集群通信安全，k8s各组件通信使用TLS证书对通信进行加密。工具采用CloudFlare的PKI工具集[cfssl](https://github.com/cloudflare/cfssl)

#### 安装

```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
mv cfssl_linux-amd64 /usr/local/bin/cfssl

wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x cfssl-certinfo_linux-amd64
mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo

```
#### CA证书
- CA配置文件

```
 cat ca-config.json
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
```
1. ca-config.json： 可以定义多个 profiles，分别指定不同的过期时间、使用场景等参数；后续在签名证书时使用某个 profile。
2. signing： 表示该证书可用于签名其它证书；生成的 ca.pem 证书中 CA=TRUE。
3. server auth： 表示 client 可以用该 CA 对 server 提供的证书进行验证。
4. client auth： 表示 server 可以用该 CA 对 client 提供的证书进行验证

#### 创建CA证书签名请求文件

```
cat ca-csr.json
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
```
1. CN：Common Name，kube-apiserver 从证书中提取该字段作为请求的用户名 (User Name)；浏览器使用该字段验证网站是否合法。
2. O：Organization，kube-apiserver 从证书中提取该字段作为请求用户所属的组 (Group)。

#### 生成CA证书和私钥

```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```
#### 分发证书
将生成的CA证书、秘钥文件、配置文件拷贝到 **所有机器** 的 /etc/kubernetes/ssl 目录下。

```
mkdir -p /etc/kubernetes/ssl 

cp ca* /etc/kubernetes/ssl

```
1. 分发证书不要进行压缩操作，否则可能证书会有问题。

#### 参考文档
- [Generate self-signed certificates](https://coreos.com/os/docs/latest/generate-self-signed-certificates.html)
- [Client Certificates V/s Server Certificates](https://blogs.msdn.microsoft.com/kaushal/2012/02/17/client-certificates-vs-server-certificates/)
- [Manage TLS Certificates in a Cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)




