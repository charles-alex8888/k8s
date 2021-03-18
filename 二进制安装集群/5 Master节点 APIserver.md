---
title: 5master节点组件apiserver
date: 2017-05-26 12:12:57
categories: 
- K8S部署
tags:
- K8S部署
---

## **准备

```sh
	#kubectl 链接api
	mkdir -p ~/.kube/;
    cp /etc/kubernetes/admin.kubeconfig ~/.kube/config
	#kubectl子命令补全
    yum install -y bash-completion
    source <(kubectl completion bash)
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
	#如果你是zsh 将bash替换为zsh即可
```



## **UnitFILE

```sh
cat >/usr/lib/systemd/system/kube-apiserver.service <<'EOF'
[Unit]
Description=Kubernetes API Server
Documentation=https:/github.com/kubernetes/kubernetes
After=network.target

[Service]
ExecStart=/opt/kube/bin/kube-apiserver \
  --authorization-mode=Node,RBAC \
  --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeClaimResize,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,Priority,PodPreset \
  --advertise-address={{ NODE_IP }} \
  --bind-address={{ NODE_IP }}  \
  --insecure-port=0 \
  --secure-port=6443 \
  --allow-privileged=true \
  --apiserver-count=1 \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/data/kubelog/apiserver/audit.log \
  --enable-swagger-ui=true \
  --storage-backend=etcd3 \
  --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt \
  --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key \
  --etcd-servers=https://192.168.1.71:2379,https://192.168.1.81:2379,https://192.168.1.82:2379 \
  --event-ttl=1h \
  --enable-bootstrap-token-auth \
  --client-ca-file=/etc/kubernetes/pki/ca.crt \
  --kubelet-https \
  --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt \
  --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key \
  --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \
  --runtime-config=api/all,settings.k8s.io/v1alpha1=true \
  --service-cluster-ip-range=10.96.0.0/12 \
  --service-node-port-range=30000-32767 \
  --service-account-key-file=/etc/kubernetes/pki/sa.pub \
  --tls-cert-file=/etc/kubernetes/pki/apiserver.crt \
  --tls-private-key-file=/etc/kubernetes/pki/apiserver.key \
  --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt \
  --requestheader-username-headers=X-Remote-User \
  --requestheader-group-headers=X-Remote-Group \
  --requestheader-allowed-names=front-proxy-client \
  --requestheader-extra-headers-prefix=X-Remote-Extra- \
  --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt \
  --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key \
  --feature-gates=PodShareProcessNamespace=true \
  --v=2

Restart=on-failure
RestartSec=10s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
```

##--apiserver-count=1 是apiserver进程在集群中运行的数量 是一个整数 记得根据情况修改

## **各节点替换内容

```sh
##替换当前节点的ip
sed -i 's/{{ NODE_IP }}/192.168.1.71/g' /usr/lib/systemd/system/kube-apiserver.service 

## 
```

## **启动

```sh
mkdir -p /etc/kubernetes/manifests /var/lib/kubelet /var/log/kubernetes /data/kubelog/apiserver/

systemctl daemon-reload && systemctl enable kube-apiserver && systemctl start kube-apiserver
```

