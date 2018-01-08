#当前部署的机器名称(随便定义，只要能区分不同机器即可)
NODE_NAME=etcd-node1  

#当前部署的机器 IP
NODE_IP=192.168.18.74 

#etcd 集群所有机器 IP
NODE_IPS=192.168.18.74 192.168.18.82 192.168.18.83

#集群间通信的IP和端口
ETCD_NODES=etcd-node1=https://192.168.18.74:2380,etcd-node2=https://192.168.18.82:2380,etcd-node3=https://192.168.18.83:2380
