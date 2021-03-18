---
title: 9coredns
date: 2017-05-26 12:12:57
categories: 
- K8S部署
tags:
- K8S部署
---

## **部署coredns

###   1 下载清单

```sh
      mkdir coredns && cd coredns
      wget https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/coredns.yaml.sed
      wget https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/deploy.sh
```



###   2 将镜像下载到本地 推送到内网harbor，可选 但推荐

```sh
		#你下载的coredns.yaml.sed 中并不一定是此版本 按照coredns.yaml.sed文件中的版本操作
	  docker pull coredns/coredns:1.7.0
      docker tag coredns/coredns:1.7.0 hb.sp.com/coredns/coredns:1.7.0
      docker push hb.sp.com/coredns/coredns:1.7.0
```



```sh
将image地址改为本地库 事先去harbor创建好项目：
  原：coredns/coredns:1.7.0
  新: hb.sp.com/coredns/coredns:1.7.0
  
  sed -i "s@coredns/coredns:1.7.0@hb.sp.com/coredns/coredns:1.7.0@g" coredns.yaml.sed
  ##验证
  cat coredns.yaml.sed |grep image
    image: hb.sp.com/coredns/coredns:1.7.0
    imagePullPolicy: IfNotPresent
```

###   3  部署

```sh
# 这里的IP 需要与apiserver 启动参数--service-cluster-ip-range=10.96.0.0/12 中的一样
#10.96.0.10 是coredns 的svc地址
bash deploy.sh -i 10.96.0.10 -r "10.96.0.0/12" -s -t coredns.yaml.sed |kubectl apply -f -
```