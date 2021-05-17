# docker

# 二进制安装k8s

~~~bash
#!/bin/bash
# auther: boge
# descriptions:  the shell scripts will use ansible to deploy K8S at binary for siample

# 传参检测
[ $# -ne 6 ] && echo -e "Usage: $0 rootpasswd netnum nethosts cri cni k8s-cluster-name\nExample: bash $0 bogedevops 10.0.1 201\ 202\ 203\ 204 [containerd|docker] [calico|flannel] test\n" && exit 11 

# 变量定义
export release=3.0.0
export k8s_ver=v1.19.7  # v1.20.2, v1.19.7, v1.18.15, v1.17.17
rootpasswd=$1
netnum=$2
nethosts=$3
cri=$4
cni=$5
clustername=$6
if ls -1v ./kubeasz*.tar.gz &>/dev/null;then software_packet="$(ls -1v ./kubeasz*.tar.gz )";else software_packet="";fi
pwd="/etc/kubeasz"


# deploy机器升级软件库
if cat /etc/redhat-release &>/dev/null;then
    yum update -y
else
    apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y
    [ $? -ne 0 ] && apt-get -yf install
fi

# deploy机器检测python环境
python2 -V &>/dev/null
if [ $? -ne 0 ];then
    if cat /etc/redhat-release &>/dev/null;then
        yum install gcc openssl-devel bzip2-devel 
        wget https://www.python.org/ftp/python/2.7.16/Python-2.7.16.tgz
        tar xzf Python-2.7.16.tgz
        cd Python-2.7.16
        ./configure --enable-optimizations
        make altinstall
        ln -s /usr/bin/python2.7 /usr/bin/python
        cd -
    else
        apt-get install -y python2.7 && ln -s /usr/bin/python2.7 /usr/bin/python
    fi
fi

# deploy机器设置pip安装加速源
if [[ $clustername != 'aws' ]]; then
mkdir ~/.pip
cat > ~/.pip/pip.conf <<CB
[global]
index-url = https://mirrors.aliyun.com/pypi/simple
[install]
trusted-host=mirrors.aliyun.com

CB
fi


# deploy机器安装相应软件包
if cat /etc/redhat-release &>/dev/null;then
    yum install git python-pip sshpass -y
    [ -f ./get-pip.py ] && python ./get-pip.py || {
    wget https://bootstrap.pypa.io/2.7/get-pip.py && python get-pip.py
    }
else
    apt-get install git python-pip sshpass -y
    [ -f ./get-pip.py ] && python ./get-pip.py || {
    wget https://bootstrap.pypa.io/2.7/get-pip.py && python get-pip.py
    }
fi
python -m pip install --upgrade "pip < 21.0"

pip -V
pip install --no-cache-dir ansible netaddr


# 在deploy机器做其他node的ssh免密操作
for host in `echo "${nethosts}"`
do
    echo "============ ${netnum}.${host} ===========";

    if [[ ${USER} == 'root' ]];then
        [ ! -f /${USER}/.ssh/id_rsa ] &&\
        ssh-keygen -t rsa -P '' -f /${USER}/.ssh/id_rsa
    else
        [ ! -f /home/${USER}/.ssh/id_rsa ] &&\
        ssh-keygen -t rsa -P '' -f /home/${USER}/.ssh/id_rsa
    fi
    sshpass -p ${rootpasswd} ssh-copy-id -o StrictHostKeyChecking=no ${USER}@${netnum}.${host}

    if cat /etc/redhat-release &>/dev/null;then
        ssh -o StrictHostKeyChecking=no ${USER}@${netnum}.${host} "yum update -y"
    else
        ssh -o StrictHostKeyChecking=no ${USER}@${netnum}.${host} "apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y"
        [ $? -ne 0 ] && ssh -o StrictHostKeyChecking=no ${USER}@${netnum}.${host} "apt-get -yf install"
    fi
done


# deploy机器下载k8s二进制安装脚本

if [[ ${software_packet} == '' ]];then
    curl -C- -fLO --retry 3 https://github.com/easzlab/kubeasz/releases/download/${release}/ezdown
    sed -ri "s+^(K8S_BIN_VER=).*$+\1${k8s_ver}+g" ezdown
    chmod +x ./ezdown
    # 使用工具脚本下载
    ./ezdown -D && ./ezdown -P
else
    tar xvf ${software_packet} -C /etc/
    chmod +x ${pwd}/{ezctl,ezdown}
fi

# 初始化一个名为my的k8s集群配置

CLUSTER_NAME="$clustername"
${pwd}/ezctl new ${CLUSTER_NAME}
if [[ $? -ne 0 ]];then
    echo "cluster name [${CLUSTER_NAME}] was exist in ${pwd}/clusters/${CLUSTER_NAME}."
    exit 1
fi

if [[ ${software_packet} != '' ]];then
    # 设置参数，启用离线安装
    sed -i 's/^INSTALL_SOURCE.*$/INSTALL_SOURCE: "offline"/g' ${pwd}/clusters/${CLUSTER_NAME}/config.yml
fi


# to check ansible service
ansible all -m ping

#---------------------------------------------------------------------------------------------------




#修改二进制安装脚本配置 config.yml

sed -ri "s+^(CLUSTER_NAME:).*$+\1 \"${CLUSTER_NAME}\"+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml

## k8s上日志及容器数据存独立磁盘步骤（参考阿里云的）

[ ! -d /var/lib/container ] && mkdir -p /var/lib/container/{kubelet,docker}

## cat /etc/fstab     
# UUID=105fa8ff-bacd-491f-a6d0-f99865afc3d6 /                       ext4    defaults        1 1
# /dev/vdb /var/lib/container/ ext4 defaults 0 0
# /var/lib/container/kubelet /var/lib/kubelet none defaults,bind 0 0
# /var/lib/container/docker /var/lib/docker none defaults,bind 0 0

## tree -L 1 /var/lib/container
# /var/lib/container
# ├── docker
# ├── kubelet
# └── lost+found

# docker data dir
DOCKER_STORAGE_DIR="/var/lib/container/docker"
sed -ri "s+^(STORAGE_DIR:).*$+STORAGE_DIR: \"${DOCKER_STORAGE_DIR}\"+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml
# containerd data dir
CONTAINERD_STORAGE_DIR="/var/lib/container/containerd"
sed -ri "s+^(STORAGE_DIR:).*$+STORAGE_DIR: \"${CONTAINERD_STORAGE_DIR}\"+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml
# kubelet logs dir
KUBELET_ROOT_DIR="/var/lib/container/kubelet"
sed -ri "s+^(KUBELET_ROOT_DIR:).*$+KUBELET_ROOT_DIR: \"${KUBELET_ROOT_DIR}\"+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml
if [[ $clustername != 'aws' ]]; then
    # docker aliyun repo
    REG_MIRRORS="https://pqbap4ya.mirror.aliyuncs.com"
    sed -ri "s+^REG_MIRRORS:.*$+REG_MIRRORS: \'[\"${REG_MIRRORS}\"]\'+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml
fi
# [docker]信任的HTTP仓库
sed -ri "s+127.0.0.1/8+${netnum}.0/24+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml
# disable dashboard auto install
sed -ri "s+^(dashboard_install:).*$+\1 \"no\"+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml


# 融合配置准备
CLUSEER_WEBSITE="${CLUSTER_NAME}k8s.gtapp.xyz"
lb_num=$(grep -wn '^MASTER_CERT_HOSTS:' ${pwd}/clusters/${CLUSTER_NAME}/config.yml |awk -F: '{print $1}')
lb_num1=$(expr ${lb_num} + 1)
lb_num2=$(expr ${lb_num} + 2)
sed -ri "${lb_num1}s+.*$+  - "${CLUSEER_WEBSITE}"+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml
sed -ri "${lb_num2}s+(.*)$+#\1+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml

# node节点最大pod 数
MAX_PODS="120"
sed -ri "s+^(MAX_PODS:).*$+\1 ${MAX_PODS}+g" ${pwd}/clusters/${CLUSTER_NAME}/config.yml



# 修改二进制安装脚本配置 hosts
# clean old ip
sed -ri '/192.168.1.1/d' ${pwd}/clusters/${CLUSTER_NAME}/hosts
sed -ri '/192.168.1.2/d' ${pwd}/clusters/${CLUSTER_NAME}/hosts
sed -ri '/192.168.1.3/d' ${pwd}/clusters/${CLUSTER_NAME}/hosts
sed -ri '/192.168.1.4/d' ${pwd}/clusters/${CLUSTER_NAME}/hosts

# 输入准备创建ETCD集群的主机位
echo "enter etcd hosts here (example: 203 202 201) ↓"
read -p "" ipnums
for ipnum in `echo ${ipnums}`
do
    echo $netnum.$ipnum
    sed -i "/\[etcd/a $netnum.$ipnum"  ${pwd}/clusters/${CLUSTER_NAME}/hosts
done

# 输入准备创建KUBE-MASTER集群的主机位
echo "enter kube-master hosts here (example: 202 201) ↓"
read -p "" ipnums
for ipnum in `echo ${ipnums}`
do
    echo $netnum.$ipnum
    sed -i "/\[kube_master/a $netnum.$ipnum"  ${pwd}/clusters/${CLUSTER_NAME}/hosts
done

# 输入准备创建KUBE-NODE集群的主机位
echo "enter kube-node hosts here (example: 204 203) ↓"
read -p "" ipnums
for ipnum in `echo ${ipnums}`
do
    echo $netnum.$ipnum
    sed -i "/\[kube_node/a $netnum.$ipnum"  ${pwd}/clusters/${CLUSTER_NAME}/hosts
done

# 配置容器运行时CNI
case ${cni} in
    flannel)
    sed -ri "s+^CLUSTER_NETWORK=.*$+CLUSTER_NETWORK=\"${cni}\"+g" ${pwd}/clusters/${CLUSTER_NAME}/hosts
    ;;
    calico)
    sed -ri "s+^CLUSTER_NETWORK=.*$+CLUSTER_NETWORK=\"${cni}\"+g" ${pwd}/clusters/${CLUSTER_NAME}/hosts
    ;;
    *)
    echo "cni need be flannel or calico."
    exit 11
esac

# 配置K8S的ETCD数据备份的定时任务
if cat /etc/redhat-release &>/dev/null;then
    if ! grep -w '94.backup.yml' /var/spool/cron/root &>/dev/null;then echo "00 00 * * * `which ansible-playbook` ${pwd}/playbooks/94.backup.yml &> /dev/null" >> /var/spool/cron/root;else echo exists ;fi
    chown root.crontab /var/spool/cron/root
    chmod 600 /var/spool/cron/root
else
    if ! grep -w '94.backup.yml' /var/spool/cron/crontabs/root &>/dev/null;then echo "00 00 * * * `which ansible-playbook` ${pwd}/playbooks/94.backup.yml &> /dev/null" >> /var/spool/cron/crontabs/root;else echo exists ;fi
    chown root.crontab /var/spool/cron/crontabs/root
    chmod 600 /var/spool/cron/crontabs/root
fi
rm /var/run/cron.reboot
service crond restart 




#---------------------------------------------------------------------------------------------------
# 准备开始安装了
rm -rf ${pwd}/{dockerfiles,docs,.gitignore,pics,dockerfiles} &&\
find ${pwd}/ -name '*.md'|xargs rm -f
read -p "Enter to continue deploy k8s to all nodes >>>" YesNobbb

# now start deploy k8s cluster 
cd ${pwd}/

# to prepare CA/certs & kubeconfig & other system settings 
${pwd}/ezctl setup ${CLUSTER_NAME} 01
sleep 1
# to setup the etcd cluster
${pwd}/ezctl setup ${CLUSTER_NAME} 02
sleep 1
# to setup the container runtime(docker or containerd)
case ${cri} in
    containerd)
    sed -ri "s+^CONTAINER_RUNTIME=.*$+CONTAINER_RUNTIME=\"${cri}\"+g" ${pwd}/clusters/${CLUSTER_NAME}/hosts
    ${pwd}/ezctl setup ${CLUSTER_NAME} 03
    ;;
    docker)
    sed -ri "s+^CONTAINER_RUNTIME=.*$+CONTAINER_RUNTIME=\"${cri}\"+g" ${pwd}/clusters/${CLUSTER_NAME}/hosts
    ${pwd}/ezctl setup ${CLUSTER_NAME} 03
    ;;
    *)
    echo "cri need be containerd or docker."
    exit 11
esac
sleep 1
# to setup the master nodes
${pwd}/ezctl setup ${CLUSTER_NAME} 04
sleep 1
# to setup the worker nodes
${pwd}/ezctl setup ${CLUSTER_NAME} 05
sleep 1
# to setup the network plugin(flannel、calico...)
${pwd}/ezctl setup ${CLUSTER_NAME} 06
sleep 1
# to setup other useful plugins(metrics-server、coredns...)
${pwd}/ezctl setup ${CLUSTER_NAME} 07
sleep 1
# [可选]对集群所有节点进行操作系统层面的安全加固  https://github.com/dev-sec/ansible-os-hardening
#ansible-playbook roles/os-harden/os-harden.yml
#sleep 1
cd `dirname ${software_packet:-/tmp}`


k8s_bin_path='/opt/kube/bin'


echo "-------------------------  k8s version list  ---------------------------"
${k8s_bin_path}/kubectl version
echo
echo "-------------------------  All Healthy status check  -------------------"
${k8s_bin_path}/kubectl get componentstatus
echo
echo "-------------------------  k8s cluster info list  ----------------------"
${k8s_bin_path}/kubectl cluster-info
echo
echo "-------------------------  k8s all nodes list  -------------------------"
${k8s_bin_path}/kubectl get node -o wide
echo
echo "-------------------------  k8s all-namespaces's pods list   ------------"
${k8s_bin_path}/kubectl get pod --all-namespaces
echo
echo "-------------------------  k8s all-namespaces's service network   ------"
${k8s_bin_path}/kubectl get svc --all-namespaces
echo
echo "-------------------------  k8s welcome for you   -----------------------"
echo

# you can use k alias kubectl to siample
echo "alias k=kubectl && complete -F __start_kubectl k" >> ~/.bashrc

# get dashboard url
${k8s_bin_path}/kubectl cluster-info|grep dashboard|awk '{print $NF}'|tee -a /root/k8s_results

# get login token
${k8s_bin_path}/kubectl -n kube-system describe secret $(${k8s_bin_path}/kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')|grep 'token:'|awk '{print $NF}'|tee -a /root/k8s_results
echo
echo "you can look again dashboard and token info at  >>> /root/k8s_results <<<"
#echo ">>>>>>>>>>>>>>>>> You can excute command [ source ~/.bashrc ] <<<<<<<<<<<<<<<<<<<<"
echo ">>>>>>>>>>>>>>>>> You need to excute command [ reboot ] to restart all nodes <<<<<<<<<<<<<<<<<<<<"
rm -f $0
[ -f ${software_packet} ] && rm -f ${software_packet}
#rm -f ${pwd}/roles/deploy/templates/${USER_NAME}-csr.json.j2
#sed -ri "s+${USER_NAME}+admin+g" ${pwd}/roles/prepare/tasks/main.yml

~~~



# k8s的API对象

1. Namespace	                  命名空间实现同一集群资源上的隔离

2. Pod                                    k8s的最小运行单元

3. ReplicasSet                      实现pod的平滑迭代更新及回滚（不需要我们操作）

4. Deployment                    发布无状态应用

5. Health Check                   Readliness/Liveness/maxUnavalivable服务健康状态检查

6. Service,Endpoint            实现同一lables下多个pod流量负载均衡

7. Labels                               标签，服务件选择访问的重要依据
8. Ingress                             k8s的流量入口
9. DaemonSet                    用来发布守护应用，例如部署CNI插件

10. HPA                                  Horizontal Pod Autoscaler 自动水平伸缩

11. Volume                           存储卷

12. Pv,Pvc,StorageClass     持久化存储，持久化存储生命，动态存储pv

13. StatefulSet                    用来发布有状态应用

14. Job,CronJob                  一次性任务及定时任务

15. Configmap, secret      服务配置及服务加密配置

16. kube-proxy.                 提供service服务流量转发的功能支持（不需要我们操作）

17. Events                          k8s事件流，可以用来监控相关事件（不需要我们操作）

18. RBAC, serviceAccount, rolebindings, clusterrole, clusterrlebindings    基于角色的访问控制



# namespace and pod 

##### 1. namespace基本操作

~~~
# 查看namespace
kubectl get ns

# 创建namespace
kubectl create ns test

# 删除namespace
kubectl delete ns test
~~~



##### 2. pod基本操作

~~~
# 创建pod
kubectl run nginx --image=nginx

# 查看
kubectl get pod -n test -o wide
kubectl get pod -n test -w -o wide

# 进入pod
kubectl exec -it nginx -- sh

# 查看pod详情
kubectl describe pod nginx

# 查看日志
kubectl logs nginx 
~~~



##### 3. pod禁止调度与驱逐

~~~
# 禁止调度到某节点
kubectl cordon <node_name>

# 恢复
kubectl uncordon <node_name>

# 驱逐某节点上的pod(daemonSet除外)
kubectl drain <node_name>

# 驱逐DaemonSet
kubectl drain <node_name> --ignore-daemonsets --force --delete-emptydir-data
~~~



# Deployment

##### 1. 命令行模式基本操作

~~~
# 创建deployment
kubectl create deployment nginx --image=nginx

# 查看创建的资源
kubectl get deploy,rs,pod

# 扩缩容
kubectl scale deploy nginx --replicas=2

# 更改镜像版本
kubectl set image deployment/nginx nginx=nginx:1.19.7 --record

# 查看deployment历史版本
kubectl rollout history deployment/nginx

# 回滚
kubectl rollout undo deployment nginx --to-version=2
~~~



##### 2. 声明式基本操作

~~~
# 生成deplyment的yaml文件
kubectl create deployment nginx --image-nginx --dry-run=client -o yaml > nginx.yaml

# 创建
kubectl apply -f nginx.yaml

# 查看创建的资源
kubectl get deployment,rs,pod

# 删除
kubectl delete deployment nginx
~~~



##### 部署过程

~~~
1. kubectl 发送部署请求到API Server
2. API Server通知Controller Manager创建一个deployment资源（scale扩容）
3. Scheduler执行调度任务，将副本数量发不到节点上
4. 节点上的kubelet创建并运行pod

**
		应用配置和当前服务状态信息都是保存在etcd中，执行kubectl get pod等操作时API Server会从ETCD中读取数据 calico(网络插件）会为每个pod分配一个ip（此ip会随着pod的重启而发生改变）
~~~



# pod 健康检测

##### pod重启策略

```
Always: 容器失效时，由kubelet自动重启
OnFailure: 容器终止运行且退出码不为0时，由kubelet自动重启
Never: 无论容器运行状态如何，kubelet都不会重启该容器
```

##### liveness  存活检测

```
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    name: myapp
spec:
  restartPolicy: OnFailure
  containers:
  - name: myapp
    image: busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 10
      periodSeconds: 5
    resources:
      limits:
        memory: "128Mi"
        cpu: "500m"
    ports:
      - containerPort: 80
```

##### readiness 就绪检测

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: test
spec:
  replicas: 10
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: busybox
        resources:
          limits:
            memory: "128Mi"
            cpu: "500m"
        ports:
        - containerPort: 80
        args:
        - /bin/bash
        - -c
        - sleep 10; touch /tmp/healthy; sleep 100
        readinessProbe:
          exec:
            command:
              - cat
              - /tmp/healthy
          initialDelaySeconds: 10
          periodSeconds: 5
          
** 
# 检测不通过，流量被阻断，容器标记为不可用，不会重启容器
# 如果更新版本导致readiness检测不过，会新老版本同时存在，pod数量会超出replicas设定的数量（超35%）
        strategy:
          rollingUpdate:
            maxSurge: 35%
            maxUnavailable: 35%
          type: RollingUpdate
```

##### 结合使用存活和就绪探针

~~~
        readinessProbe:
            initialDelaySeconds: 30
            periodSeconds: 10
            tcpSocket:
                port: 8080
        livenessProbe:
            periodSeconds: 30
            httpGet:
                port: 8080
                path: /health/check
~~~



# HPA 自动水平伸缩pod

##### 1. 配置

~~~yaml
			 resources:
			 	 limits:
			 	   cpu: "1"
			 	   memory: 2Gi
			 	 requests:
			 	   cpu: "1"
			 	   memory: 2Gi
			 	   
***
前提:dns服务和metrics-server正常运行
~~~

##### 2. 测试

~~~bash
kubectl run -it --rm busy box --image=busybpx -- sh
while :;do wget -q -O- http://web; done
~~~



# Service

##### 1. 命令行模式操作

~~~
# 创建svc
kubectl expose deployment nginx --port=80 --target-port=80 service/nginx exposed -n test

# 查看svc 
kubectl get svc -n test

# 修改svc类型
kubectl patch svc nginx -p '{"spec":{"type":"NodePort"}}'
~~~



##### 2. 声明式操作



##### 3. svc对接集群外资源

```
# subsets下配置为集群外的资源

kind: Service
apiVersion: v1
metadata:
  name:  mysvc
spec:
  selector:
    app:  nginx
  type:  ClusterIP
  ports:
  - port:  80
    protocol: TCP
    targetPort:  8080
  
---
kind: Endpoints
apiVersion: v1
metadata: 
  name: mysvc
subsets:
- addresses:
  - ip: 10.0.1.100
    nodeName: 10.0.1.100 
  ports:
  - port: 9999
    protocl: TCP
```



# Labels

# ingress

# 配置管理

# statefulSet

# RBAC (role-based access control)角色访问控制

##### 资源关系

~~~
                Role  RoleBinding               # 只在执行的namespace中生效
ServiceAccount
                ClusterRole  ClusterRoleBinding # 不受namespace限制，在整个k8s集群中生效
~~~

##### rbac的作用

~~~
1. 保证在k8s上运行的pod服务具有相应的集群权限
2. 创建能访问k8s相应资源、拥有对应权限的kube-config配置给到使用k8s的人员，来作为连接k8s的授权凭证
~~~

##### 基本操作

~~~
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
~~~



##### 创建对指定namespace有所有权限的kube-config

~~~bash
#!/bin/bash
#
# This Script based on  https://jeremievallee.com/2018/05/28/kubernetes-rbac-namespace-user.html
# K8s'RBAC doc:         https://kubernetes.io/docs/reference/access-authn-authz/rbac
# Gitlab'CI/CD doc:     hhttps://docs.gitlab.com/ee/user/permissions.html#running-pipelines-on-protected-branches
#
# In honor of the remarkable Windson

BASEDIR="$(dirname "$0")"
folder="$BASEDIR/kube_config"

echo -e "All namespaces is here: \n$(kubectl get ns|awk 'NR!=1{print $1}')"
echo "endpoint server if local network you can use $(kubectl cluster-info |awk '/Kubernetes/{print $NF}')"

namespace=$1
endpoint=$(echo "$2" | sed -e 's,https\?://,,g')

if [[ -z "$endpoint" || -z "$namespace" ]]; then
    echo "Use "$(basename "$0")" NAMESPACE ENDPOINT";
    exit 1;
fi

if ! kubectl get ns|awk 'NR!=1{print $1}'|grep -w "$namespace";then kubectl create ns "$namespace";else echo "namespace: $namespace was exist." ;fi

echo "---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $namespace-user
  namespace: $namespace
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $namespace-user-full-access
  namespace: $namespace
rules:
- apiGroups: ['', 'extensions', 'apps', 'metrics.k8s.io']
  resources: ['*']
  verbs: ['*']
- apiGroups: ['batch']
  resources:
  - jobs
  - cronjobs
  verbs: ['*']
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $namespace-user-view
  namespace: $namespace
subjects:
- kind: ServiceAccount
  name: $namespace-user
  namespace: $namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: $namespace-user-full-access
---
# https://kubernetes.io/zh/docs/concepts/policy/resource-quotas/
apiVersion: v1
kind: ResourceQuota
metadata:
  name: $namespace-compute-resources
  namespace: $namespace
spec:
  hard:
    pods: "10"
    services: "10"
    persistentvolumeclaims: "5"
    requests.cpu: "1"
    requests.memory: 2Gi
    limits.cpu: "2"
    limits.memory: 4Gi" | kubectl apply -f -
    
kubectl -n $namespace describe quota $namespace-compute-resources
mkdir -p $folder
tokenName=$(kubectl get sa $namespace-user -n $namespace -o "jsonpath={.secrets[0].name}")
token=$(kubectl get secret $tokenName -n $namespace -o "jsonpath={.data.token}" | base64 --decode)
certificate=$(kubectl get secret $tokenName -n $namespace -o "jsonpath={.data['ca\.crt']}")

echo "apiVersion: v1
kind: Config
preferences: {}
clusters:
- cluster:
    certificate-authority-data: $certificate
    server: https://$endpoint
  name: $namespace-cluster
users:
- name: $namespace-user
  user:
    as-user-extra: {}
    client-key-data: $certificate
    token: $token
contexts:
- context:
    cluster: $namespace-cluster
    namespace: $namespace
    user: $namespace-user
  name: $namespace
current-context: $namespace" > $folder/$namespace.kube.conf
~~~



#####  创建对指定namespace有所有权限的kube-config（在已有的namespace中创建）

~~~bash
#!/bin/bash


BASEDIR="$(dirname "$0")"
folder="$BASEDIR/kube_config"

echo -e "All namespaces is here: \n$(kubectl get ns|awk 'NR!=1{print $1}')"
echo "endpoint server if local network you can use $(kubectl cluster-info |awk '/Kubernetes/{print $NF}')"

namespace=$1
endpoint=$(echo "$2" | sed -e 's,https\?://,,g')

if [[ -z "$endpoint" || -z "$namespace" ]]; then
    echo "Use "$(basename "$0")" NAMESPACE ENDPOINT";
    exit 1;
fi


echo "---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $namespace-user
  namespace: $namespace
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $namespace-user-full-access
  namespace: $namespace
rules:
- apiGroups: ['', 'extensions', 'apps', 'metrics.k8s.io']
  resources: ['*']
  verbs: ['*']
- apiGroups: ['batch']
  resources:
  - jobs
  - cronjobs
  verbs: ['*']
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $namespace-user-view
  namespace: $namespace
subjects:
- kind: ServiceAccount
  name: $namespace-user
  namespace: $namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: $namespace-user-full-access" | kubectl apply -f -

mkdir -p $folder
tokenName=$(kubectl get sa $namespace-user -n $namespace -o "jsonpath={.secrets[0].name}")
token=$(kubectl get secret $tokenName -n $namespace -o "jsonpath={.data.token}" | base64 --decode)
certificate=$(kubectl get secret $tokenName -n $namespace -o "jsonpath={.data['ca\.crt']}")

echo "apiVersion: v1
kind: Config
preferences: {}
clusters:
- cluster:
    certificate-authority-data: $certificate
    server: https://$endpoint
  name: $namespace-cluster
users:
- name: $namespace-user
  user:
    as-user-extra: {}
    client-key-data: $certificate
    token: $token
contexts:
- context:
    cluster: $namespace-cluster
    namespace: $namespace
    user: $namespace-user
  name: $namespace
current-context: $namespace" > $folder/$namespace.kube.conf
~~~



#####  同上，创建只读权限的

~~~bash
#!/bin/bash


BASEDIR="$(dirname "$0")"
folder="$BASEDIR/kube_config"

echo -e "All namespaces is here: \n$(kubectl get ns|awk 'NR!=1{print $1}')"
echo "endpoint server if local network you can use $(kubectl cluster-info |awk '/Kubernetes/{print $NF}')"

namespace=$1
endpoint=$(echo "$2" | sed -e 's,https\?://,,g')

if [[ -z "$endpoint" || -z "$namespace" ]]; then
    echo "Use "$(basename "$0")" NAMESPACE ENDPOINT";
    exit 1;
fi


echo "---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $namespace-user-readonly
  namespace: $namespace
  
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $namespace-user-readonly-access
  namespace: $namespace
rules:
- apiGroups: ['', 'extensions', 'apps', 'metrics.k8s.io']
  resources: ['pods', 'pods/log']
  verbs: ['get', 'list', 'watch']
- apiGroups: ['batch']
  resources: ['jobs', 'cronjobs']
  verbs: ['get', 'list', 'watch']
  
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $namespace-user-view-readonly
  namespace: $namespace
subjects:
- kind: ServiceAccount
  name: $namespace-user-readonly
  namespace: $namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: $namespace-user-readonly-access" | kubectl apply -f -
  
 mkdir -p $folder
tokenName=$(kubectl get sa $namespace-user-readonly -n $namespace -o "jsonpath={.secrets[0].name}")
token=$(kubectl get secret $tokenName -n $namespace -o "jsonpath={.data.token}" | base64 --decode)
certificate=$(kubectl get secret $tokenName -n $namespace -o "jsonpath={.data['ca\.crt']}")

echo "apiVersion: v1
kind: Config
preferences: {}
clusters:
- cluster:
    certificate-authority-data: $certificate
    server: https://$endpoint
  name: $namespace-cluster-readonly
users:
- name: $namespace-user-readonly
  user:
    as-user-extra: {}
    client-key-data: $certificate
    token: $token
contexts:
- context:
    cluster: $namespace-cluster-readonly
    namespace: $namespace
    user: $namespace-user-readonly
  name: $namespace
current-context: $namespace" > $folder/$namespace-readonly.kube.conf
~~~



##### 多集群配置融合的创建只读权限的

~~~ bash
#!/bin/bash
# describe: create k8s cluster all namespaces resources with readonly clusterrole, no exec 、delete ...

# look system default to study:
# kubectl describe clusterrole view

# restore all change:
#kubectl -n kube-system delete sa all-readonly-${clustername}
#kubectl delete clusterrolebinding all-readonly-${clustername}
#kubectl delete clusterrole all-readonly-${clustername}


clustername=$1

Help(){
    echo "Use "$(basename "$0")" ClusterName(example: k8s1|k8s2|k8s3|delk8s1|delk8s2|delk8s3|3in1)";
    exit 1;
}

if [[ -z "${clustername}" ]]; then
    Help
fi

case ${clustername} in
    k8s1)
    endpoint="https://x.x.x.x:123456"
    ;;
    k8s2)
    endpoint="https://x.x.x.x:123456"
    ;;
    k8s3)
    endpoint="https://x.x.x.x:123456"
    ;;
    delk8s1)
    kubectl -n kube-system delete sa all-readonly-k8s1
    kubectl delete clusterrolebinding all-readonly-k8s1
    kubectl delete clusterrole all-readonly-k8s1
    echo "${clustername} successful."
    exit 0
    ;;
    delk8s2)
    kubectl -n kube-system delete sa all-readonly-k8s2
    kubectl delete clusterrolebinding all-readonly-k8s2
    kubectl delete clusterrole all-readonly-k8s2
    echo "${clustername} successful."
    exit 0
    ;;
    delk8s3)
    kubectl -n kube-system delete sa all-readonly-k8s3
    kubectl delete clusterrolebinding all-readonly-k8s3
    kubectl delete clusterrole all-readonly-k8s3
    echo "${clustername} successful."
    exit 0
    ;;
    3in1)
    KUBECONFIG=./all-readonly-k8s1.conf:all-readonly-k8s2.conf:all-readonly-k8s3.conf kubectl config view --flatten > ./all-readonly-3in1.conf
    kubectl --kubeconfig=./all-readonly-3in1.conf config use-context "k8s3"
    kubectl --kubeconfig=./all-readonly-3in1.conf config set-context "k8s3" --namespace="default"
    kubectl --kubeconfig=./all-readonly-3in1.conf config get-contexts
    echo -e "\n\n\n"
    cat ./all-readonly-3in1.conf |base64 -w 0
    exit 0
    ;;
    *)
    Help
esac

echo "---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: all-readonly-${clustername}
rules:
- apiGroups:
  - ''
  resources:
  - configmaps
  - endpoints
  - persistentvolumes
  - persistentvolumeclaims
  - pods
  - replicationcontrollers
  - replicationcontrollers/scale
  - serviceaccounts
  - services
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ''
  resources:
  - bindings
  - events
  - limitranges
  - namespaces/status
  - pods/log
  - pods/status
  - replicationcontrollers/status
  - resourcequotas
  - resourcequotas/status
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ''
  resources:
  - namespaces
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - controllerrevisions
  - daemonsets
  - deployments
  - deployments/scale
  - replicasets
  - replicasets/scale
  - statefulsets
  - statefulsets/scale
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - autoscaling
  resources:
  - horizontalpodautoscalers
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - batch
  resources:
  - cronjobs
  - jobs
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - extensions
  resources:
  - daemonsets
  - deployments
  - deployments/scale
  - ingresses
  - networkpolicies
  - replicasets
  - replicasets/scale
  - replicationcontrollers/scale
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - policy
  resources:
  - poddisruptionbudgets
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - networking.k8s.io
  resources:
  - networkpolicies
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - metrics.k8s.io
  resources:
  - pods
  verbs:
  - get
  - list
  - watch" | kubectl apply -f -
  
kubectl -n kube-system create sa all-readonly-${clustername}
kubectl create clusterrolebinding all-readonly-${clustername} --clusterrole=all-readonly-${clustername} --serviceaccount=kube-system:all-readonly-${clustername}

tokenName=$(kubectl -n kube-system get sa all-readonly-${clustername} -o "jsonpath={.secrets[0].name}")
token=$(kubectl -n kube-system get secret $tokenName -o "jsonpath={.data.token}" | base64 --decode)
certificate=$(kubectl -n kube-system get secret $tokenName -o "jsonpath={.data['ca\.crt']}")

echo "apiVersion: v1
kind: Config
preferences: {}
clusters:
- cluster:
    certificate-authority-data: $certificate
    server: $endpoint
  name: all-readonly-${clustername}-cluster
users:
- name: all-readonly-${clustername}
  user:
    as-user-extra: {}
    client-key-data: $certificate
    token: $token
contexts:
- context:
    cluster: all-readonly-${clustername}-cluster
    user: all-readonly-${clustername}
  name: ${clustername}
current-context: ${clustername}" > ./all-readonly-${clustername}.conf

~~~



# 日志收集

# 私有镜像仓库 harbor

~~~
# 官方文档
https://goharbor.io/docs/2.2.0/
~~~



# prometheus监控

##### 

#### prometheus operator 资源

~~~
Prometheus     声明式创建和管理Prometheus Server实例
ServiceMonitor 声明式的管理监控配置
PrometheusRule 声明式的管理告警配置
Alertmanager   声明式的创建和管理Altermanager实例
~~~

##### 

#### 安装部署

~~~
~~~



#### 使用prometheus监控ingress-nginx

##### 创建 servicemonitor配置让prometheus能发现ingress-nginx的metrics

~~~
# vim servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app: ingress-nginx
  name: nginx-ingress-scraping
  namespace: ingress-nginx
spec:
  endpoints:
  - interval: 30s
    path: /metrics
    port: metrics
  jobLabel: app
  namespaceSelector:
    matchNames:
    - ingress-nginx
  selector:
    matchLabels:
      app: ingress-nginx
~~~



##### 创建

~~~
kubectl apply -f servicemonitor.yaml 

kubectl -n ingress-nginx get servicemonitors.monitoring.coreos.com

# 查看报错信息
kubectl -n monitoring logs prometheus-k8s-0 -c prometheus |grep error
~~~



##### 修改prometheus的clusterrole

~~~
#kubectl edit clusterrole prometheus-k8s

#------ 原始的rules -------
rules:
- apiGroups:
  - ""
  resources:
  - nodes/metrics
  verbs:
  - get
- nonResourceURLs:
  - /metrics
  verbs:
  - get
#---------------------------

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-k8s
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  - services
  - endpoints
  - pods
  - nodes/proxy
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - configmaps
  - nodes/metrics
  verbs:
  - get
- nonResourceURLs:
  - /metrics
  verbs:
  - get
~~~



#### 使用Prometheus来监控二进制部署的ETCD集群

##### 查看etcd暴露了哪些监控指标

~~~
# curl --cacert /etc/kubernetes/ssl/ca.pem --cert /etc/etcd/ssl/etcd.pem  --key /etc/etcd/ssl/etcd-key.pem https://10.0.1.201:2379/metrics
~~~

##### 配置使ETCD能被prometheus发现并监控

~~~
# 首先把ETCD的证书创建为secret
kubectl -n monitoring create secret generic etcd-certs --from-file=/etc/etcd/ssl/etcd.pem   --from-file=/etc/etcd/ssl/etcd-key.pem   --from-file=/etc/kubernetes/ssl/ca.pem

# 接着在prometheus里面引用这个secrets
kubectl -n monitoring edit prometheus k8s 

spec:
...
  secrets:
  - etcd-certs

# 保存退出后，prometheus会自动重启服务pod以加载这个secret配置，过一会，我们进pod来查看下是不是已经加载到ETCD的证书了
# kubectl -n monitoring exec -it prometheus-k8s-0 -c prometheus  -- sh 
/prometheus $ ls /etc/prometheus/secrets/etcd-certs/
~~~



##### 创建service、endpoints以及ServiceMonitor

```
# vim prometheus-etcd.yaml 
apiVersion: v1
kind: Service
metadata:
  name: etcd-k8s
  namespace: monitoring
  labels:
    k8s-app: etcd
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: api
    port: 2379
    protocol: TCP
---
apiVersion: v1
kind: Endpoints
metadata:
  name: etcd-k8s
  namespace: monitoring
  labels:
    k8s-app: etcd
subsets:
- addresses:
  - ip: 10.0.1.201
  - ip: 10.0.1.202
  - ip: 10.0.1.203
  ports:
  - name: api
    port: 2379
    protocol: TCP
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: etcd-k8s
  namespace: monitoring
  labels:
    k8s-app: etcd-k8s
spec:
  jobLabel: k8s-app
  endpoints:
  - port: api
    interval: 30s
    scheme: https
    tlsConfig:
      caFile: /etc/prometheus/secrets/etcd-certs/ca.pem
      certFile: /etc/prometheus/secrets/etcd-certs/etcd.pem
      keyFile: /etc/prometheus/secrets/etcd-certs/etcd-key.pem
      #use insecureSkipVerify only if you cannot use a Subject Alternative Name
      insecureSkipVerify: true 
  selector:
    matchLabels:
      k8s-app: etcd
  namespaceSelector:
    matchNames:
    - monitoring
    
# 创建
kubectl apply -f prometheus-etcd.yaml 
```



##### 用grafana来展示被监控的ETCD指标

~~~
1. 在grafana官网模板中心搜索etcd，下载这个json格式的模板文件
https://grafana.com/dashboards/3070

2.然后打开自己先部署的grafana首页，
点击左边菜单栏四个小正方形方块HOME --- Manage
再点击右边 Import dashboard --- 
点击Upload .json File 按钮，上传上面下载好的json文件 etcd_rev3.json，
然后在prometheus选择数据来源
点击Import，即可显示etcd集群的图形监控信息
~~~



#### 数据持久化

##### prometheus数据持久化配置

~~~
# 注意这下面的statefulset服务就是我们需要做数据持久化的地方
# kubectl -n monitoring get statefulset,pod|grep prometheus-k8s
statefulset.apps/prometheus-k8s      2/2     5h41m
pod/prometheus-k8s-0                       2/2     Running   1          19m
pod/prometheus-k8s-1                       2/2     Running   1          19m

# 看下我们之前准备的StorageClass动态存储
# kubectl get sc
NAME       PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-boge   nfs-provisioner-01   Retain          Immediate           false                  4d

# 准备prometheus持久化的pvc配置
# kubectl -n monitoring edit prometheus k8s

spec:
......
  storage:
    volumeClaimTemplate:
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: "nfs-boge"
        selector:
          matchLabels:
            app: my-example-prometheus
        resources:
          requests:
            storage: 1Gi

# 上面修改保存退出后，过一会我们查看下pvc创建情况，以及pod内的数据挂载情况
# kubectl -n monitoring get pvc
NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
prometheus-k8s-db-prometheus-k8s-0   Bound    pvc-055e6b11-31b7-4503-ba2b-4f292ba7bd06   1Gi        RWO            nfs-boge       17s
prometheus-k8s-db-prometheus-k8s-1   Bound    pvc-249c344b-3ef8-4a5d-8003-b8ce8e282d32   1Gi        RWO            nfs-boge       17s


# kubectl -n monitoring exec -it prometheus-k8s-0 -c prometheus -- sh
/prometheus $ df -Th
......
10.0.1.201:/nfs_dir/monitoring-prometheus-k8s-db-prometheus-k8s-0-pvc-055e6b11-31b7-4503-ba2b-4f292ba7bd06/prometheus-db
                     nfs4           97.7G      9.4G     88.2G  10% /prometheus
~~~



##### grafana配置持久化存储配置

~~~
# 保存pvc为grafana-pvc.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: grafana
  namespace: monitoring
spec:
  storageClassName: nfs-boge
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi

# 开始创建pvc
# kubectl apply -f grafana-pvc.yaml 

# 看下创建的pvc
# kubectl -n monitoring get pvc
NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
grafana                              Bound    pvc-394a26e1-3274-4458-906e-e601a3cde50d   1Gi        RWX            nfs-boge       3s
prometheus-k8s-db-prometheus-k8s-0   Bound    pvc-055e6b11-31b7-4503-ba2b-4f292ba7bd06   1Gi        RWO            nfs-boge       6m46s
prometheus-k8s-db-prometheus-k8s-1   Bound    pvc-249c344b-3ef8-4a5d-8003-b8ce8e282d32   1Gi        RWO            nfs-boge       6m46s


# 编辑grafana的deployment资源配置
# kubectl -n monitoring edit deployments.apps grafana 

# 旧的配置
      volumes:
      - emptyDir: {}
        name: grafana-storage
# 替换成新的配置
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana

# 同时加入下面的env环境变量，将登陆密码进行固定修改
    spec:
      containers:
      ......
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: admin
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin321

# 过一会，等grafana重启完成后，用上面的新密码进行登陆
# kubectl -n monitoring get pod -w|grep grafana
grafana-5698bf94f4-prbr2               0/1     Running   0          3s
grafana-5698bf94f4-prbr2               1/1     Running   0          4s

# 因为先前的数据并未持久化，所以会发现先导入的ETCD模板已消失，这时重新再导入一次，后面重启也不会丢了
~~~



#### 发送报警

~~~
下载boge-webhook.zip
https://cloud.189.cn/t/B3EFZvnuMvuu (访问码:h1wx)

# 监控报警规划修改   
vim ./manifests/prometheus/prometheus-rules.yaml
# 更新   
kubectl apply -f ./manifests/prometheus/prometheus-rules.yaml
~~~

~~~
# 通过这里可以获取需要创建的报警配置secret名称
# kubectl -n monitoring edit statefulsets.apps alertmanager-main
...
      volumes:
      - name: config-volume
        secret:
          defaultMode: 420
          secretName: alertmanager-main
...

# 注意事先在配置文件 alertmanager.yaml 里面编辑好收件人等信息 ，再执行下面的命令

kubectl create secret generic  alertmanager-main --from-file=alertmanager.yaml -n monitoring
~~~

##### 报警配置文件 alertmanager.yaml

~~~
# global块配置下的配置选项在本配置文件内的所有配置项下可见
global:
  # 在Alertmanager内管理的每一条告警均有两种状态: "resolved"或者"firing". 在altermanager首次发送告警通知后, 该告警会一直处于firing状态,设置resolve_timeout可以指定处于firing状态的告警间隔多长时间会被设置为resolved状态, 在设置为resolved状态的告警后,altermanager不会再发送firing的告警通知.
#  resolve_timeout: 1h
  resolve_timeout: 10m

  # 告警通知模板
templates:
- '/etc/altermanager/config/*.tmpl'

# route: 根路由,该模块用于该根路由下的节点及子路由routes的定义. 子树节点如果不对相关配置进行配置，则默认会从父路由树继承该配置选项。每一条告警都要进入route，即要求配置选项group_by的值能够匹配到每一条告警的至少一个labelkey(即通过POST请求向altermanager服务接口所发送告警的labels项所携带的<labelname>)，告警进入到route后，将会根据子路由routes节点中的配置项match_re或者match来确定能进入该子路由节点的告警(由在match_re或者match下配置的labelkey: labelvalue是否为告警labels的子集决定，是的话则会进入该子路由节点，否则不能接收进入该子路由节点).
route:
  # 例如所有labelkey:labelvalue含cluster=A及altertname=LatencyHigh labelkey的告警都会被归入单一组中
  group_by: ['job', 'altername', 'cluster', 'service','severity']
  # 若一组新的告警产生，则会等group_wait后再发送通知，该功能主要用于当告警在很短时间内接连产生时，在group_wait内合并为单一的告警后再发送
#  group_wait: 30s
  group_wait: 10s
  # 再次告警时间间隔
#  group_interval: 5m
  group_interval: 20s
  # 如果一条告警通知已成功发送，且在间隔repeat_interval后，该告警仍然未被设置为resolved，则会再次发送该告警通知
#  repeat_interval: 12h
  repeat_interval: 1m
  # 默认告警通知接收者，凡未被匹配进入各子路由节点的告警均被发送到此接收者
  receiver: 'webhook'
  # 上述route的配置会被传递给子路由节点，子路由节点进行重新配置才会被覆盖

  # 子路由树
  routes:
  # 该配置选项使用正则表达式来匹配告警的labels，以确定能否进入该子路由树
  # match_re和match均用于匹配labelkey为service,labelvalue分别为指定值的告警，被匹配到的告警会将通知发送到对应的receiver
  - match_re:
      service: ^(foo1|foo2|baz)$
    receiver: 'webhook'
    # 在带有service标签的告警同时有severity标签时，他可以有自己的子路由，同时具有severity != critical的告警则被发送给接收者team-ops-wechat,对severity == critical的告警则被发送到对应的接收者即team-ops-pager
    routes:
    - match:
        severity: critical
      receiver: 'webhook'
  # 比如关于数据库服务的告警，如果子路由没有匹配到相应的owner标签，则都默认由team-DB-pager接收
  - match:
      service: database
    receiver: 'webhook'
  # 我们也可以先根据标签service:database将数据库服务告警过滤出来，然后进一步将所有同时带labelkey为database
  - match:
      severity: critical
    receiver: 'webhook'
# 抑制规则，当出现critical告警时 忽略warning
inhibit_rules:
- source_match:
    severity: 'critical'
  target_match:
    severity: 'warning'
  # Apply inhibition if the alertname is the same.
  #   equal: ['alertname', 'cluster', 'service']
  #
# 收件人配置
receivers:
- name: 'webhook'
  webhook_configs:
  - url: 'http://alertmanaer-dingtalk-svc.kube-system//b01bdc063/boge/getjson'
    send_resolved: true
~~~

#####

~~~
# 监控其他服务的prometheus规则配置
https://github.com/samber/awesome-prometheus-alerts
~~~



# 基于gitlab的CI-CD

# 持久化存储nfs

#### 部署nfs-server

1. 安装

   > yum -y install nfs-utils

2.  创建nfs挂载目录

   > mkdir /nfs_dir
   >
   > chown nobody.nobody /nfs_dir

   

3. 修改nfs-server的配置

   > echo '/nfs_dir *(rw,sync,no_root_squash)' > /etc/exports

4. 重启服务

   > systemctl restart rpcbind.service
   >
   > systemctl restart nfs-utils.service
   >
   > systemctl restart nfs-server.service

5. 配置开启自启

   > systemctl enable nfs-server.service

6. 验证nfs-server是否能访问

   > Showmount -e <nfs-server_ip>



#### 使用pv 和 pvc

1. 创建pv

   > mkdir /nfs_dir/nginx-pv
   >
   > kubectl apply -f nginx-pv.yaml
   >
   > kubectl get pv

   ~~~
   kind: PersistentVolume
   apiVersion: v1
   metadata:
     name: nginx-pv
     labels: 
       type: nginx-pv
   spec:
   	capacity:
   		stroage: 1Gi
   	accessModes:
   		- ReadWriteOnce
   	persistentVolumeReclaimPolicy: Recycle
   	storageClassName: nfs
   	nfs:
   		path: /nfs_dir/nginx-pv
   		server: <nfs_server_host>
   ~~~

   

2. 创建pvc

   > kubectl apply -f nginx-pvc.yaml
   >
   > kubectl get pvc
   >
   > Kubectl

   ~~~yaml
   kind: PersistentVolumeClaim
   apiVersion: v1
   metadata: 
   	name: nginx-pvc
   spec:
   	accessModes:
   		- ReadWriteOnce
   	resources:
   		requests:
   			storage: 1Gi
   	storageClassName: nfs
   	selector:
   		matchLabels:
   			type: nginx-pv
   ~~~

3.  挂载pvc

   > kubectl apply -f nginx.yaml
   >
   > kubectl  get pod,svc 

   

   ~~~yaml
   kind:Service
   apiVersion: v1
   metadata: 
   	labels:
   		app: nginx
   	name: nginx
   spec:
   	ports:
   	- port: 80
   	  protocol: TCP
   	  targetPort: 80
   	selector:
   	  app: nginx
   	
   ---
   kind: Deployment
   apiVersion: apps/v1
   metadata:
   	labels: 
   		app: nginx
   	name: nginx
   spec:
   	replicas: 1
   	selector:
   		matchLabels:
   			app: nginx
   	template:
   		metadata: 
   			labels:
   				app: nginx
   		spec:
   			containers:
   			- image: nginx
   			  name: nginx
   			  volumeMounts:
   			  	- name: html-files
   			  		mountPath: "/usr/share/nginx/html"
   			  volumes:
   			  	- name: html-files
   			  		persistentVolumeClaim:
   			  			claimName: nginx-pvc
   ~~~

   

# ingress

​		Ingress只需要一个公网IP就能为K8s上所有的服务提供访问，Ingress工作在7层（HTTP），Ingress会根据请求的主机名以及路径来决定把请求转发到相应的服务，要在K8s上面使用Ingress，我们就需要在K8s上部署Ingress-controller控制器，只有它在K8s集群中运行，Ingress依次才能正常工作。Ingress-controller控制器有很多种，比如traefik，但我们这里要用到ingress-nginx这个控制器，它的底层就是用Openresty融合nginx和一些lua规则等实现的。

```
Ingress是允许入站连接到达集群服务的一组规则。即介于物理网络和群集svc之间的一组转发规则。 
其实就是实现L4 L7的负载均衡:
注意：这里的Ingress并非将外部流量通过Service来转发到服务pod上，而只是通过Service来找到对应的Endpoint来发现pod进行转发

   
    internet
        |
   [ Ingress ]   ---> [ Services ] ---> [ Endpoint ]
   --|-----|--                                 |
   [ Pod,pod,...... ]<-------------------------|
```

 		

### aliyun-ingress-controller

​		aliyun-ingress-controller有一个很重要的修改，就是它支持路由配置的动态更新，大家用过Nginx的可以知道，在修改完Nginx的配置，我们是需要进行nginx -s reload来重加载配置才能生效的，在K8s上，这个行为也是一样的，但由于K8s运行的服务会非常多，所以它的配置更新是非常频繁的，因此，如果不支持配置动态更新，对于在高频率变化的场景下，Nginx频繁Reload会带来较明显的请求访问问题：

1. 造成一定的QPS抖动和访问失败情况
2. 对于长连接服务会被频繁断掉
3. 造成大量的处于shutting down的Nginx Worker进程，进而引起内存膨胀
4. 

##### 部署aliyun-ingress-controller   aliyun-ingress-nginx.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
  labels:
    app: ingress-nginx

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
  labels:
    app: ingress-nginx

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: nginx-ingress-controller
  labels:
    app: ingress-nginx
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
      - endpoints
      - nodes
      - pods
      - secrets
      - namespaces
      - services
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - "extensions"
      - "networking.k8s.io"
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - create
      - patch
  - apiGroups:
      - "extensions"
      - "networking.k8s.io"
    resources:
      - ingresses/status
    verbs:
      - update
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - create
  - apiGroups:
      - ""
    resources:
      - configmaps
    resourceNames:
      - "ingress-controller-leader-nginx"
    verbs:
      - get
      - update

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: nginx-ingress-controller
  labels:
    app: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: nginx-ingress-controller
subjects:
  - kind: ServiceAccount
    name: nginx-ingress-controller
    namespace: ingress-nginx

---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: ingress-nginx
  name: nginx-ingress-lb
  namespace: ingress-nginx
spec:
  # DaemonSet need:
  # ----------------
  type: ClusterIP
  # ----------------
  # Deployment need:
  # ----------------
#  type: NodePort
  # ----------------
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
  - name: https
    port: 443
    targetPort: 443
    protocol: TCP
  - name: metrics
    port: 10254
    protocol: TCP
    targetPort: 10254
  selector:
    app: ingress-nginx

---
kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
  labels:
    app: ingress-nginx
data:
  keep-alive: "75"
  keep-alive-requests: "100"
  upstream-keepalive-connections: "10000"
  upstream-keepalive-requests: "100"
  upstream-keepalive-timeout: "60"
  allow-backend-server-header: "true"
  enable-underscores-in-headers: "true"
  generate-request-id: "true"
  http-redirect-code: "301"
  ignore-invalid-headers: "true"
  log-format-upstream: '{"@timestamp": "$time_iso8601","remote_addr": "$remote_addr","x-forward-for": "$proxy_add_x_forwarded_for","request_id": "$req_id","remote_user": "$remote_user","bytes_sent": $bytes_sent,"request_time": $request_time,"status": $status,"vhost": "$host","request_proto": "$server_protocol","path": "$uri","request_query": "$args","request_length": $request_length,"duration": $request_time,"method": "$request_method","http_referrer": "$http_referer","http_user_agent":  "$http_user_agent","upstream-sever":"$proxy_upstream_name","proxy_alternative_upstream_name":"$proxy_alternative_upstream_name","upstream_addr":"$upstream_addr","upstream_response_length":$upstream_response_length,"upstream_response_time":$upstream_response_time,"upstream_status":$upstream_status}'
  max-worker-connections: "65536"
  worker-processes: "2"
  proxy-body-size: 20m
  proxy-connect-timeout: "10"
  proxy_next_upstream: error timeout http_502
  reuse-port: "true"
  server-tokens: "false"
  ssl-ciphers: ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA
  ssl-protocols: TLSv1 TLSv1.1 TLSv1.2
  ssl-redirect: "false"
  worker-cpu-affinity: auto

---
kind: ConfigMap
apiVersion: v1
metadata:
  name: tcp-services
  namespace: ingress-nginx
  labels:
    app: ingress-nginx

---
kind: ConfigMap
apiVersion: v1
metadata:
  name: udp-services
  namespace: ingress-nginx
  labels:
    app: ingress-nginx

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
  labels:
    app: ingress-nginx
  annotations:
    component.version: "v0.30.0"
    component.revision: "v1"
spec:
  # Deployment need:
  # ----------------
#  replicas: 1
  # ----------------
  selector:
    matchLabels:
      app: ingress-nginx
  template:
    metadata:
      labels:
        app: ingress-nginx
      annotations:
        prometheus.io/port: "10254"
        prometheus.io/scrape: "true"
        scheduler.alpha.kubernetes.io/critical-pod: ""
    spec:
      # DaemonSet need:
      # ----------------
      hostNetwork: true
      # ----------------
      serviceAccountName: nginx-ingress-controller
      priorityClassName: system-node-critical
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - ingress-nginx
              topologyKey: kubernetes.io/hostname
            weight: 100
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: type
                operator: NotIn
                values:
                - virtual-kubelet
      containers:
        - name: nginx-ingress-controller
          image: registry.cn-beijing.aliyuncs.com/acs/aliyun-ingress-controller:v0.30.0.2-9597b3685-aliyun
          args:
            - /nginx-ingress-controller
            - --configmap=$(POD_NAMESPACE)/nginx-configuration
            - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
            - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
            - --publish-service=$(POD_NAMESPACE)/nginx-ingress-lb
            - --annotations-prefix=nginx.ingress.kubernetes.io
            - --enable-dynamic-certificates=true
            - --v=2
          securityContext:
            allowPrivilegeEscalation: true
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
            runAsUser: 101
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - name: http
              containerPort: 80
            - name: https
              containerPort: 443
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 10
#          resources:
#            limits:
#              cpu: "1"
#              memory: 2Gi
#            requests:
#              cpu: "1"
#              memory: 2Gi
          volumeMounts:
          - mountPath: /etc/localtime
            name: localtime
            readOnly: true
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
          type: File
      nodeSelector:
        boge/ingress-controller-ready: "true"
      tolerations:
      - operator: Exists

      initContainers:
      - command:
        - /bin/sh
        - -c
        - |
          mount -o remount rw /proc/sys
          sysctl -w net.core.somaxconn=65535
          sysctl -w net.ipv4.ip_local_port_range="1024 65535"
          sysctl -w fs.file-max=1048576
          sysctl -w fs.inotify.max_user_instances=16384
          sysctl -w fs.inotify.max_user_watches=524288
          sysctl -w fs.inotify.max_queued_events=16384
        image: registry.cn-beijing.aliyuncs.com/acs/busybox:v1.29.2
        imagePullPolicy: Always
        name: init-sysctl
        securityContext:
          privileged: true
          procMount: Default

---
## Deployment need for aliyun'k8s:
#apiVersion: v1
#kind: Service
#metadata:
#  annotations:
#    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-id: "lb-xxxxxxxxxxxxxxxxxxx"
#    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-force-override-listeners: "true"
#  labels:
#    app: nginx-ingress-lb
#  name: nginx-ingress-lb-local
#  namespace: ingress-nginx
#spec:
#  externalTrafficPolicy: Local
#  ports:
#  - name: http
#    port: 80
#    protocol: TCP
#    targetPort: 80
#  - name: https
#    port: 443
#    protocol: TCP
#    targetPort: 443
#  selector:
#    app: ingress-nginx
#  type: LoadBalancer


```



##### DaemonSet

```shell
# kubectl  apply -f aliyun-ingress-nginx.yaml 
namespace/ingress-nginx created
serviceaccount/nginx-ingress-controller created
clusterrole.rbac.authorization.k8s.io/nginx-ingress-controller created
clusterrolebinding.rbac.authorization.k8s.io/nginx-ingress-controller created
service/nginx-ingress-lb created
configmap/nginx-configuration created
configmap/tcp-services created
configmap/udp-services created
daemonset.apps/nginx-ingress-controller created

# 这里是以daemonset资源的形式进行的安装
# DaemonSet资源和Deployment的yaml配置类似，但不同的是Deployment可以在每个node上运行多个pod副本，但daemonset在每个node上只能运行一个pod副本
# 这里正好就借运行ingress-nginx的情况下，把daemonset这个资源做下讲解

# 我们查看下pod，会发现空空如也，为什么会这样呢？
# kubectl -n ingress-nginx get pod
注意上面的yaml配置里面，我使用了节点选择配置，只有打了我指定lable标签的node节点，也会被允许调度pod上去运行
      nodeSelector:
        boge/ingress-controller-ready: "true"

# 我们现在来打标签
# kubectl label node 10.0.1.201 boge/ingress-controller-ready=true
node/10.0.1.201 labeled
# kubectl label node 10.0.1.202 boge/ingress-controller-ready=true
node/10.0.1.202 labeled

# 接着可以看到pod就被调试到这两台node上启动了
# kubectl -n ingress-nginx get pod -o wide
NAME                             READY   STATUS    RESTARTS   AGE    IP           NODE         NOMINATED NODE   READINESS GATES
nginx-ingress-controller-lchgr   1/1     Running   0          9m1s   10.0.1.202   10.0.1.202   <none>           <none>
nginx-ingress-controller-x87rp   1/1     Running   0          9m6s   10.0.1.201   10.0.1.201   <none>           <none>
```

我们基于前面学到的deployment和service，来创建一个nginx的相应服务资源，保存为nginx.yaml：

> 注意：记得把前面测试的资源删除掉，以防冲突

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx
  name: nginx
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx

---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx
        name: nginx

```

运行它：

```shell
# kubectl apply -f nginx.yaml 
service/nginx created
deployment.apps/nginx created
```

然后准备nginx的ingress配置，保留为nginx-ingress.yaml，并执行它：

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  rules:
    - host: nginx.boge.com
      http:
        paths:
          - backend:
              serviceName: nginx
              servicePort: 80
            path: /
```

```shell
# kubectl apply -f nginx-ingress.yaml 
ingress.extensions/nginx-ingress created

#查看创建的ingress资源
# kubectl get ingress
NAME            CLASS    HOSTS            ADDRESS   PORTS   AGE
nginx-ingress   <none>   nginx.boge.com             80      13s

# 我们在其它节点上，加下本地hosts，来测试下效果
10.0.1.201 nginx.boge.com

# 可以看到请求成功了
[root@node-2 ~]# curl nginx.boge.com
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

# 回到201节点上，看下ingress-nginx的日志
[root@node-1 ~]# kubectl -n ingress-nginx logs --tail=1 nginx-ingress-controller-x87rp  
{"@timestamp": "2020-11-26T18:16:53+08:00","remote_addr": "10.0.1.202","x-forward-for": "10.0.1.202","request_id": "74440b6d92aca4d64600ffa85c1dee15","remote_user": "-","bytes_sent": 851,"request_time": 0.004,"status": 200,"vhost": "nginx.boge.com","request_proto": "HTTP/1.1","path": "/","request_query": "-","request_length": 78,"duration": 0.004,"method": "GET","http_referrer": "-","http_user_agent":  "curl/7.29.0","upstream-sever":"default-nginx-80","proxy_alternative_upstream_name":"","upstream_addr":"172.20.217.65:80","upstream_response_length":612,"upstream_response_time":0.003,"upstream_status":200}
```



在生产环境中，如果是自建机房，我们通常会在至少2台node节点上运行有ingress-nginx的pod，那么有必要在这两台node上面部署负载均衡软件做调度，来起到高可用的作用，这里我们用haproxy+keepalived，如果你的生产环境是在云上，假设是阿里云，那么你只需要购买一个负载均衡器SLB，将运行有ingress-nginx的pod的节点服务器加到这个SLB的后端来，然后将请求域名和这个SLB的公网IP做好解析即可

注意在每台node节点上有已经部署有了个haproxy软件，来转发apiserver的请求的，那么，我们只需要选取两台节点，部署keepalived软件并重新配置haproxy，来生成VIP达到ha的效果，这里我们选择在其中两台node节点（10.0.1.202、203）上部署

node上现在已有的haproxy配置：

```shell
# cat /etc/haproxy/haproxy.cfg 
global
        log /dev/log    local1 warning
        chroot /var/lib/haproxy
        user haproxy
        group haproxy
        daemon
        nbproc 1

defaults
        log     global
        timeout connect 5s
        timeout client  10m
        timeout server  10m

listen kube-master
        bind 127.0.0.1:6443
        mode tcp
        option tcplog
        option dontlognull
        option dontlog-normal
        balance roundrobin 
        server 10.0.1.201 10.0.1.201:6443 check inter 10s fall 2 rise 2 weight 1
        server 10.0.1.202 10.0.1.202:6443 check inter 10s fall 2 rise 2 weight 1
```

开始新增ingress端口的转发，修改haproxy配置如下（注意两台节点都记得修改）：

```shell
# cat /etc/haproxy/haproxy.cfg 
global
        log /dev/log    local1 warning
        chroot /var/lib/haproxy
        user haproxy
        group haproxy
        daemon
        nbproc 1

defaults
        log     global
        timeout connect 5s
        timeout client  10m
        timeout server  10m

listen kube-master
        bind 127.0.0.1:6443
        mode tcp
        option tcplog
        option dontlognull
        option dontlog-normal
        balance roundrobin 
        server 10.0.1.201 10.0.1.201:6443 check inter 10s fall 2 rise 2 weight 1
        server 10.0.1.202 10.0.1.202:6443 check inter 10s fall 2 rise 2 weight 1

listen ingress-http
        bind 0.0.0.0:80
        mode tcp
        option tcplog
        option dontlognull
        option dontlog-normal
        balance roundrobin
        server 10.0.1.201 10.0.1.201:80 check inter 2000 fall 2 rise 2 weight 1
        server 10.0.1.202 10.0.1.202:80 check inter 2000 fall 2 rise 2 weight 1

listen ingress-https
        bind 0.0.0.0:443
        mode tcp
        option tcplog
        option dontlognull
        option dontlog-normal
        balance roundrobin
        server 10.0.1.201 10.0.1.201:443 check inter 2000 fall 2 rise 2 weight 1
        server 10.0.1.202 10.0.1.202:443 check inter 2000 fall 2 rise 2 weight 1
```

然后在两台node上分别安装keepalived并进行配置：

```shell
# 安装keepalived
yum install -y keepalived

# 编辑配置修改为如下：
# 这里是node 10.0.1.203
global_defs {
    router_id lb-master
}

vrrp_script check-haproxy {
    script "killall -0 haproxy"
    interval 5
    weight -60
}

vrrp_instance VI-kube-master {
    state MASTER
    priority 120
    unicast_src_ip 10.0.1.203
    unicast_peer {
        10.0.1.204
    }
    dont_track_primary
    interface ens32  # 注意这里的网卡名称修改成你机器真实的内网网卡名称，可用命令ip addr查看
    virtual_router_id 111
    advert_int 3
    track_script {
        check-haproxy
    }
    virtual_ipaddress {
        10.0.1.222
    }
}


# 这里是node 10.0.1.204
global_defs {
    router_id lb-master
}

vrrp_script check-haproxy {
    script "killall -0 haproxy"
    interval 5
    weight -60
}

vrrp_instance VI-kube-master {
    state MASTER
    priority 120
    unicast_src_ip 10.0.1.204
    unicast_peer {
        10.0.1.203
    }
    dont_track_primary
    interface ens32
    virtual_router_id 111
    advert_int 3
    track_script {
        check-haproxy
    }
    virtual_ipaddress {
        10.0.1.222
    }
}

```

全部安装配置完成后，在两台node上重启服务：

```shell
# 重启服务
systemctl restart haproxy.service
systemctl restart keepalived.service

# 查看运行状态
systemctl status haproxy.service 
systemctl status keepalived.service

# 添加开机自启动（haproxy默认安装好就添加了自启动）
systemctl enable keepalived.service
# 查看是否添加成功
systemctl is-enabled keepalived.service 
enabled就代表添加成功了

# 同时我可查看下VIP是否已经生成
[root@node-4 ~]# ip a|grep 222                           
    inet 10.0.1.222/32 scope global ens32
```

现在我们找一台带图形桌面的机器，绑定下hosts，来试试ingress吧

```shell
# 添加一条hosts
10.0.1.222 nginx.boge.com
```



做到这里，是不是有点成就感了呢，在已经知道了ingress能给我们带来什么后，我们回过头来理解Ingress的工作原理，这样掌握ingress会更加稳固，这也是我平时学习的方法

如下图，Client客户端对`nginx.boge.com`进行DNS查询，DNS服务器（我们这里是配的本地hosts）返回了Ingress控制器的IP（也就是我们的VIP：10.0.1.222）。然后Client客户端向Ingress控制器发送HTTP请求，并在请求Host头中指定`nginx.boge.com`。Ingress控制器从该头部确定Client客户端是想访问哪个服务，通过与该服务并联的Endpoint对象查看具体的Pod IP，并将Client客户端的请求转发给其中一个pod。

生产环境正常情况下大部分是一个Ingress对应一个Service服务，但在一些特殊情况，需要复用一个Ingress来访问多个服务的，下面我们来实践下

再创建一个nginx的deployment和service，注意名称修改下不要冲突了

```shell
# kubectl create deployment web --image=nginx
deployment.apps/web created

# kubectl expose deployment web --port=80 --target-port=80
service/web exposed

# 确认下创建结果
# kubectl  get deployments.apps 
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
nginx   1/1     1            1           16h
web     1/1     1            1           45s
# kubectl  get pod
NAME                    READY   STATUS    RESTARTS   AGE
nginx-f89759699-6vgr8   1/1     Running   1          16h
web-5dcb957ccc-nr2m7    1/1     Running   0          54s
# kubectl  get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.68.0.1       <none>        443/TCP   17h
nginx        ClusterIP   10.68.238.54    <none>        80/TCP    16h
web          ClusterIP   10.68.229.231   <none>        80/TCP    16s

# 接着来修改Ingress
# 注意：这里可以通过两种方式来修改K8s正在运行的资源
# 第一种：直接通过edit修改在线服务的资源来生效，这个通常用在测试环境，在实际生产中不建议这么用
kubectl edit ingress nginx-ingress

# 第二种： 通过之前创建ingress的yaml配置，在上面进行修改，再apply更新进K8s，在生产中是建议这么用的，我们这里也用这种方式来修改
# vim nginx-ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /    # 注意这里需要把进来到服务的请求重定向到/，这个和传统的nginx配置是一样的，不配会404
  name: nginx-ingress
spec:
  rules:
    - host: nginx.boge.com
      http:
        paths:
          - backend:
              serviceName: nginx
              servicePort: 80
            path: /nginx  # 注意这里的路由名称要是唯一的
          - backend:       # 从这里开始是新增加的
              serviceName: web
              servicePort: 80
            path: /web  # 注意这里的路由名称要是唯一的
# 开始创建
[root@node-1 ~]# kubectl  apply -f nginx-ingress.yaml 
ingress.extensions/nginx-ingress configured

# 同时为了更直观的看到效果，我们按前面讲到的方法来修改下nginx默认的展示页面
# kubectl exec -it nginx-f89759699-6vgr8 -- bash
echo "i am nginx" > /usr/share/nginx/html/index.html

# kubectl exec -it web-5dcb957ccc-nr2m7 -- bash
echo "i am web" > /usr/share/nginx/html/index.html
```



因为http属于是明文传输数据不安全，在生产中我们通常会配置https加密通信，现在实战下Ingress的tls配置

```shell
# 这里我先自签一个https的证书

#1. 先生成私钥key
# openssl genrsa -out tls.key 2048
Generating RSA private key, 2048 bit long modulus
..............................................................................................+++
.....+++
e is 65537 (0x10001)

#2.再基于key生成tls证书(注意：这里我用的*.boge.com，这是生成泛域名的证书，后面所有新增加的三级域名都是可以用这个证书的)
# openssl req -new -x509 -key tls.key -out tls.cert -days 360 -subj /CN=*.boge.com

# 看下创建结果
# ll
total 8
-rw-r--r-- 1 root root 1099 Nov 27 11:44 tls.cert
-rw-r--r-- 1 root root 1679 Nov 27 11:43 tls.key

# 在K8s上创建tls的secret（注意默认ns是default）
# kubectl create secret tls mytls --cert=tls.cert --key=tls.key 
secret/mytls created

# 然后修改先的ingress的yaml配置
# cat nginx-ingress.yaml 
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /    # 注意这里需要把进来到服务的请求重定向到/，这个和传统的nginx配置是一样的，不配会404
  name: nginx-ingress
spec:
  rules:
    - host: nginx.boge.com
      http:
        paths:
          - backend:
              serviceName: nginx
              servicePort: 80
            path: /nginx  # 注意这里的路由名称要是唯一的
          - backend:       # 从这里开始是新增加的
              serviceName: web
              servicePort: 80
            path: /web  # 注意这里的路由名称要是唯一的
  tls:    # 增加下面这段，注意缩进格式
      - hosts:
          - nginx.boge.com   # 这里域名和上面的对应
        secretName: mytls    # 这是我先生成的secret

# 进行更新
# kubectl  apply -f nginx-ingress.yaml         
ingress.extensions/nginx-ingress configured
```



#### secret

- 密钥类型
  - docker-registry      仓库
  - generic
  - tls                             网站证书





# ingress-nginx

##### 安装

~~~
# 给运行ingress pod的节点打标签
kubectl label nodes <node> ingress=true  

# 创建namespace
kubectl create ns ingress

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 
helm repo update
helm pull ingress-nginx/ingress-nginx 
tar xf ingress-nginx-3.19.0.tgz 

helm install ingress  ingress-nginx/ingress-nginx  \
 -n ingress\
 --set controller.hostNetwork=true \
 --set controller.kind=DaemonSet \
 --set-string controller.nodeSelector.ingress=true \
 --set controller.service.enabled=true \
 --set controller.ingressClass=nginx-ds
 
~~~

~~~
# 参考
https://nerois.github.io/
~~~

##### 配置

~~~
# 证书配置
kubectl create secret tls mgt-tls --key domain.key --cert domain.crt -n ingress

# ingress文件
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: mgt
  namespace: ns-name
  annotations:
    kubernetes.io/ingress.class: "nginx-ds"
spec:
  rules:
      #彩票后台前端
    - host: domain.com
      http:
        paths:
          - backend:
              serviceName: svc-name
              servicePort: 80
  tls:
    - secretName: mgt-tls
      hosts:
        - domain.com
~~~

##### 配置支持websocket

~~~
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-dt
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header Upgrade "websocket";
      proxy_set_header Connection "Upgrade";
    nginx.ingress.kubernetes.io/proxy-read-timeout 3600; 
    nginx.ingress.kubernetes.io/proxy-send-timeout 3600;
~~~





# nacos部署

#####  

##### 1 创建数据库配置

~~~
# kubectl apply -f nacos-cm.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: nacos-cm
  namespace: nacos
data:
  mysql.db.name: "nacos"
  mysql.port: "3306"
  mysql.host: "172.16.128.79"
  mysql.user: "nacos"
  mysql.password: "zPYYa6YLws9sbOFpkVo-iqgk"
~~~



##### 2.部署Headless Service

~~~
# kubectl apply -f nacos-headless.yaml

apiVersion: v1
kind: Service
metadata:
  name: nacos-headless
  namespace: nacos
  labels:
    app: nacos
  #annotations:
    #service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
spec:
  ports:
    - port: 8848
      name: server
      targetPort: 8848
  clusterIP: None
  selector:
    app: nacos
~~~



##### 3 通过StatefulSet部署nacos

~~~
# kubectl apply -f nacos-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nacos
  namespace: nacos
spec:
  serviceName: nacos-headless
  replicas: 3
  template:
    metadata:
      labels:
        app: nacos
      annotations:
        pod.alpha.kubernetes.io/initialized: "true"
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: "app"
                    operator: In
                    values:
                      - nacos-headless
              topologyKey: "kubernetes.io/hostname"
      containers:
        - name: k8snacos
          imagePullPolicy: Always
          image: nacos/nacos-server:latest
          resources:
            requests:
              memory: "2Gi"
              cpu: "500m"
          ports:
            - containerPort: 8848
              name: client
          env:
            - name: NACOS_REPLICAS
              value: "3"
            - name: MYSQL_SERVICE_HOST
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.host
            - name: MYSQL_SERVICE_DB_NAME
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.db.name
            - name: MYSQL_SERVICE_PORT
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.port
            - name: MYSQL_SERVICE_USER
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.user
            - name: MYSQL_SERVICE_PASSWORD
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.password
            - name: MODE
              value: "cluster"
            - name: NACOS_SERVER_PORT
              value: "8848"
            - name: PREFER_HOST_MODE
              value: "hostname"
            - name: NACOS_SERVERS
              value: "nacos-0.nacos-headless.nacos.svc.cluster.local:8848 nacos-1.nacos-headless.nacos.svc.cluster.local:8848 nacos-2.nacos-headless.nacos.svc.cluster.local:8848"
  selector:
    matchLabels:
      app: nacos
~~~



##### 4 部署普通Service（Nginx使用）

~~~
# kubectl apply -f nacos-service.yaml

apiVersion: v1
kind: Service
metadata:
  name: nacos-service
  namespace: nacos
  annotations:
    nginx.ingress.kubernetes.io/affinity: "true"
    nginx.ingress.kubernetes.io/session-cookie-name: backend
    nginx.ingress.kubernetes.io/load-balancer-method: drr


spec:
  selector:
    app: nacos
  ports:
    - name: web
      port: 80
      targetPort: 8848
~~~



##### 5 配置Ingress（可选）

~~~
kubectl apply -f nacos-ingress.yaml

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nacos-web
  namespace: nacos
  annotations:
    kubernetes.io/ingress.class: "nginx-ds"

spec:
  rules:
    - host: nacos-web.nacos-demo.com
      http:
        paths:
          - path: /
            backend:
              serviceName: nacos-service
              servicePort: web
~~~

```
172.16.128.79
```



# 实用命令

#### ip相关操作

~~~
# 查看服务器公网ip
curl ip.sb

# 查看ip网络情况
https://ping.pe/
~~~

#### 生成随机字符串

~~~
< /dev/urandom tr -cd _A-Z-a-z-0-9#-,~ | head -c ${1:-24}; echo
cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 20
~~~

#### redis 操作

~~~
# 获取hashmap的健值
HSCAN <key> 0 COUNT 10

# 获取hashmap的fields
Hkeys <kay>

# 删除指定key
HDEL <key> <key_fields>

# 批量删除key
redis-cli -p <port> -a <pass> -n 1 keys "**" | xargs redis-cli -p <port> -a <pass>  -n 1 
redis-cli -c -p <port> -h <redis_host> --tls -a -n 1 keys "**" | xargs redis-cli -c -p <port> -h <redis_host> --tls -a -n 1
~~~

#### 查找并删除文件

~~~
find . -mtime +7 -type f -exec rm -rf {} \;
find . -mtime +7 -type f | xargs rm -rf
find . -name "*.tar" -exec mv {} backup \;
find . -type f -newermt '2020-11-16 05:44:00' ! -newermt '2020-11-16 06:04:00'
~~~

#### 查看web服务器的并发请求数及其TCP连接状态

~~~
# 
netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) print a, S[a]}'

# 
netstat -nat|awk '{print$5}'|awk -F : '{print $1}'|sort|uniq -c|sort -rn

# 查看tcp各个状态的数量
netstat -na | awk '{print $6}' | sort | uniq -c | sort -nr
~~~

#### 系统性能分析

~~~
uptime
dmesg | tail
vmstat 1
mpstat -P ALL 1
pidstat 1
iostat -xz 1
free -m
sar -n DEV 1
sar -n TCP,ETCP 1
top
~~~



~~~
账号：神清气爽ya
密码：Qwer1234
~~~

