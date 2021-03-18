---
title: 3master准备
date: 2017-05-26 12:12:57
categories: 
- K8S部署
tags:
- K8S部署
---

## 所有master节点下载server端二进制包

```sh
wget https://dl.k8s.io/v1.15.2/kubernetes-server-linux-amd64.tar.gz

tar xvf kubernetes-server-linux-amd64.tar.gz && \
mkdir -p /opt/kube/bin/ && \
cp -p kubernetes/server/bin/kube{let,ctl,-apiserver,-controller-manager,-scheduler,-proxy}  /opt/kube/bin/

vim /etc/profile.d/k8s.sh
export PATH=/opt/kube/bin/:$PATH

source /etc/profile.d/k8s.sh
```



## **证书创建

所有的操作都在master01的节点上进行
在master01上创建证书，然后分发到各个节点
#所有节点创建相关目录

```sh
mkdir -p /etc/kubernetes/pki/etcd && \
cd /etc/kubernetes/pki/
```


