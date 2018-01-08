# TLS Bootstrapping 使用的 Token，可以使用命令 head -c 16 /dev/urandom | od -An -t x | tr -d ' ' 生成
BOOTSTRAP_TOKEN="c4f8933415448bd979f87a15b64f6bbe"

# etcd 集群服务地址列表
ETCD_ENDPOINTS="https://192.168.18.74:2379,https://192.168.18.82:2379,https://192.168.18.83:2379"

MASTER_IP=192.168.18.74 # 替换为 kubernetes master 集群任一机器 IP

KUBE_APISERVER="https://${MASTER_IP}:6443"

NODE_IP=192.168.18.82

NODE_NAME=k8s-slave1
