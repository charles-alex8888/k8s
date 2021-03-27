# ***命令行模式***
### 创建deployment
> kubectl create deployment nginx --image=nginx
### 查看创建的资源
> kubectl get deploy,rs,pod
### 扩缩容
> kubectl scale deplyment nginx --replicas=2
###  更改镜像版本
> kubectl set image deployment/nginx nginx=nginx:1.19.7 --record=true
### 查看deployment历史版本
> kubectl rollout history deploymentnginx
### 回滚
> kubectl rollout undo deployment nginx --to-version=2

### 部署过程
1. kubectl 发送部署请求到API Server
2. API Server通知Controller Manager创建一个deployment资源（scale扩容）
3. Scheduler执行调度任务，将副本数量发不到节点上
4. 节点上的kubelet创建并运行pod
> 应用配置和当前服务状态信息都是保存在etcd中，执行kubectl get pod等操作时API Server会从ETCD中读取数据
calico(网络插件）会为每个pod分配一个ip（此ip会随着pod的重启而发生改变）

### 禁止pod调度到该节点
~~~ bash
kubectl cordon <node_name>
# 恢复调度
kubectl uncordon <node_name>
~~~
### 驱逐该节点上的所有pod (DaemonSet除外）
~~~ bash
kubectl drain <node_name>
# 驱逐DaemonSet
kubectl drain <node_name> --ignore-daemonsets --force --delete-emptydir-data
~~~

# ***声明式***
### 生成deplyment的yaml文件
> kubectl create deployment nginx --image-nginx --dry-run -o yaml > nginx.yaml
### 创建
> kubectl apply -f nginx.yaml
### 查看创建的资源
> kubectl get deployment,rs,pod
### 删除
> kubectl delete deployment nginx
