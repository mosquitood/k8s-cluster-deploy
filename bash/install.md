# 半自动脚本安装k8s集群
- 修改主机名称

```
//永久修改
hostnamectl --static set-hostname k8s-master
```
- 修改/etc/hosts 

```
192.168.18.74 etcd-node1
192.168.18.82 etcd-node2
192.168.18.83 etcd-node3
192.168.18.74 k8s-master
192.168.18.82 k8s-slave1 
192.168.18.83 k8s-slave2
192.168.18.103 k8s-slave3
192.168.18.123 k8s-slave4
```

- 环境初始化
```
./os.sh
``` 

- CA和秘钥

```
#master节点执行
./ca/init.sh
```
  1. 分发证书: 将生成的CA证书、秘钥文件、配置文件拷贝到 所有机器 的 /etc/kubernetes/ssl 目录下。分发证书不要进行压缩操作，否则可能证书会有问题。

```
mkdir -p /etc/kubernetes/ssl 

cp ca* /etc/kubernetes/ssl
```


- Etcd集群 

 注意修改etcd/env.sh文件
```
./etcd/init.sh
```
- master节点

 注意修改master/custom.sh文件
 
 ```
 ./master/init.sh
 ```
  1. 分发 kubeconfig 文件: 将 ~/.kube/config 文件拷贝到运行 kubelet（k8s集群slave节点） 命令的机器的 ~/.kube/ 目录下。
  
 - node节点
 
  注意修改slave/custom.sh
  
  ```
  ./slave/init.sh
  ```
  
### 检测脚本
  - 相应的文件夹里面有检测脚本: check.sh

### 清理脚本
  - 相应的文件夹里面有检测脚本: clear.sh






