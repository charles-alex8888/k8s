---
title: 2docekr以及cni
date: 2017-05-26 12:12:57
categories: 
- K8S部署
tags:
- K8S部署
---

## 所有节点安装docker

- 准备仓库

```
yum install -y epel-release 
yum install -y wget yum-utils device-mapper-persistent-data conntrack lvm2 ipvsadm ipset jq iptables curl sysstat libseccomp
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo 
```



## 查看仓库内可选的版本包

```
yum list docker-ce --showduplicates | sort -r
```

## 安装  这里选择最新版

yum install -y docker-ce 

## 修改UnitFile 

```
vim /usr/lib/systemd/system/docker.service

[Service]
Environment="PATH=/opt/kube/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT

#添加以上两行 在[Service]字段

**修改daemon.json
mkdir -p /etc/docker/

cat >/etc/docker/daemon.json <<EOF
{
  "data-root": "/data/docker",
  "exec-opts": [ "native.cgroupdriver=cgroupfs" ],
  "registry-mirrors": [ "https://docker.mirrors.ustc.edu.cn", "http://hub-mirror.c.163.com" ], 
  "insecure-registries": ["127.0.0.1/8"],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "15m",
    "max-file": "3"
    },
  "storage-driver": "overlay2"
}
EOF
```



## 启动

```
##创建docker 数据目录
mkdir -p /data/docker/ && \
systemctl daemon-reload && systemctl enable docker && systemctl start docker

**验证 
docker info

**获取官方镜像 k8s.gcr.io/pause:3.1
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause-amd64:3.1



**所有节点安装CNI
https://github.com/containernetworking/plugins/releases

wget https://github.com/containernetworking/plugins/releases/download/v0.8.1/cni-plugins-linux-amd64-v0.8.1.tgz
mkdir -p /opt/cni/bin && tar -xf cni-plugins-linux-amd64-v0.8.1.tgz  -C /opt/cni/bin/

```

