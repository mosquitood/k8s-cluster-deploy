## 部署Heapster插件

- 到[heapster官网](https://github.com/kubernetes/heapster/releases)下载最新版本的heapster
- 本文档是v1.4.3版本。

配置文件目录：

```
cd deploy/kube-config/influxdb
ls *.yaml
grafana-service.yaml heapster-controller.yaml heapster-service.yaml 
influxdb-grafana-controller.yaml influxdb-service.yaml
```



- 如果不能翻墙，替换镜像为mosquitood/XXX:TAG或者其它镜像

## RBAC配置

### 定义ServiceAccount

放到了[heapster-controller.yaml](https://github.com/mosquitood/k8s-cluster-deploy/commit/28872bc8b9caecf6e27490652ba3843fb5179718)中，也可以单独定义文件。

```shell
apiVersion: v1
kind: ServiceAccount
metadata:
  name: heapster
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
```

### 绑定账户到Heapster

具体位置参考heapster-controller.yaml

```shell
serviceAccountName: heapster
```



### 为账户绑定角色和权限

为保证正常访问k8s系统，需要配置相应的权限到指定ServiceAccount

```shell
#heapster-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: heapster-binding
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:heapster
subjects:
- kind: ServiceAccount
  name: heapster
  namespace: kube-system
---
# Heapster's pod_nanny monitors the heapster deployment & its pod(s), and scales
# the resources of the deployment if necessary.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: system:pod-nanny
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
- apiGroups:
  - "extensions"
  resources:
  - deployments
  verbs:
  - get
  - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: heapster-binding
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: system:pod-nanny
subjects:
- kind: ServiceAccount
  name: heapster
  namespace: kube-system
```

## 执行所有定义文件

```
kubectl create -f .
grafana-service.yaml heapster-controller.yaml heapster-service.yaml 
influxdb-grafana-controller.yaml influxdb-service.yaml heapster-rbac.yaml
```

## 检查执行结果

```
#deployment
kubectl get deployments -n kube-system | grep -E 'heapster|monitoring'

#pod
kubectl get pods -n kube-system | grep -E 'heapster|monitoring'
```

如果检查都正常运行，则过几分钟刷新Dashboard，查看是否生效。如不生效：

1. 检查插件是否安装成功，可通过Dashboar查看日志。
2. 重新安装Dashboar插件即可。

成功生效：

![kubernetes-dashboard-heapster](/images/dashboard-heapster.png)

[完整配置文件](https://github.com/mosquitood/k8s-cluster-deploy/tree/master/addons/heapster)
