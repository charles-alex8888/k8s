---
title: 6配置 bootstrap
date: 2017-05-26 12:12:57
categories: 
- K8S部署
tags:
- K8S部署
---

## **配置 bootstrap

首先在master01建立一个变数来产生BOOTSTRAP_TOKEN,并建立bootstrap的kubeconfig文件：
接着master01建立TLS bootstrap secret来提供自动签证使用：

```sh
TOKEN_PUB=$(openssl rand -hex 3) && \
TOKEN_SECRET=$(openssl rand -hex 8) && \
BOOTSTRAP_TOKEN="${TOKEN_PUB}.${TOKEN_SECRET}"

kubectl -n kube-system create secret generic bootstrap-token-${TOKEN_PUB} \
        --type 'bootstrap.kubernetes.io/token' \
        --from-literal description="cluster bootstrap token" \
        --from-literal token-id=${TOKEN_PUB} \
        --from-literal token-secret=${TOKEN_SECRET} \
        --from-literal usage-bootstrap-authentication=true \
        --from-literal usage-bootstrap-signing=true
		
```



## **建立bootstrap的kubeconfig文件

```sh
#变量
CLUSTER_NAME="kubernetes"
KUBE_USER="kubelet-bootstrap"
KUBE_CONFIG="bootstrap.kubeconfig"
KUBE_APISERVER="https://192.168.1.71:6443"
#KUBE_APISERVER 可以是vip

#设置集群参数
kubectl config set-cluster ${CLUSTER_NAME} \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=/etc/kubernetes/${KUBE_CONFIG}
#设置客户端认证参数
kubectl config set-credentials ${KUBE_USER} \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=/etc/kubernetes/${KUBE_CONFIG}
#设置上下文参数
kubectl config set-context ${KUBE_USER}@${CLUSTER_NAME} \
  --cluster=${CLUSTER_NAME} \
  --user=${KUBE_USER} \
  --kubeconfig=/etc/kubernetes/${KUBE_CONFIG}
#设置当前使用的上下文
kubectl config use-context ${KUBE_USER}@${CLUSTER_NAME} --kubeconfig=/etc/kubernetes/${KUBE_CONFIG}
#验证文件
kubectl config view --kubeconfig=/etc/kubernetes/${KUBE_CONFIG}
```



## **授权 kubelet 可以创建 csr 请求

```sh
kubectl create clusterrolebinding kubeadm:kubelet-bootstrap \
        --clusterrole system:node-bootstrapper --group system:bootstrappers
```



## **允许 system:bootstrappers 组的所有 csr

```sh
cat <<EOF | kubectl apply -f -
# Approve all CSRs for the group "system:bootstrappers"
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: auto-approve-csrs-for-group
subjects:
- kind: Group
  name: system:bootstrappers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
  apiGroup: rbac.authorization.k8s.io
EOF
```

## **允许 kubelet 能够更新自己的证书

```sh
cat <<EOF | kubectl apply -f -
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: auto-approve-renewals-for-nodes
subjects:
- kind: Group
  name: system:nodes
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
  apiGroup: rbac.authorization.k8s.io
EOF
```

## **分发NODE节点所用到的认证文件

```sh
##node节点创建相关目录
mkdir -p /etc/kubernetes/pki /etc/kubernetes/manifests /var/lib/kubelet/
#ca
scp -rp /etc/kubernetes/pki/ca.crt  k-n1:/etc/kubernetes/pki/ca.crt
#kubeconfig
scp -rp /etc/kubernetes/bootstrap.kubeconfig k-n1:/etc/kubernetes/bootstrap.kubeconfig

```

