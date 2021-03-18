---
title: 8网络插件calico与flannel
date: 2017-05-26 12:12:57
categories: 
- K8S部署
tags:
- K8S部署
---

###calico 与 flannel 选一即可

## **calico

```sh
wget https://docs.projectcalico.org/v3.8/manifests/calico.yaml 
sed -i -e "s?192.168.0.0/16?10.244.0.0/16?g" calico.yaml
#最好下载好镜像上传至内部harbor
#然后修改此文件中的镜像指向内部harbor 
calico/cni:v3.8.9
calico/pod2daemon-flexvol:v3.8.9
calico/node:v3.8.9
calico/kube-controllers:v3.8.9
```



## **替换镜像 

```sh
sed -i "s@calico/cni:v3.8.9@hb.sp.com/calico/cni:v3.8.9@g" calico.yaml 
sed -i "s@calico/pod2daemon-flexvol:v3.8.9@hb.sp.com/calico/pod2daemon-flexvol:v3.8.9@g" calico.yaml 
sed -i "s@calico/node:v3.8.9@hb.sp.com/calico/node:v3.8.9@g" calico.yaml 
sed -i "s@calico/kube-controllers:v3.8.9@hb.sp.com/calico/kube-controllers:v3.8.9@g" calico.yaml 
```



## **启动

```sh
kubectl apply -f calico.yaml
```



## **验证

```sh
~]# kubectl get nodes
NAME          STATUS   ROLES    AGE   VERSION
k-m1.sp.com   Ready    master   9h    v1.15.12
k-n1.sp.com   Ready    node     25h   v1.15.12
k-n2.sp.com   Ready    node     24h   v1.15.12

~]# kubectl get pod -n kube-system
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-867fb4cbb9-tl9d8   1/1     Running   0          51m
calico-node-7nxjj                          1/1     Running   0          51m
calico-node-td9mh                          1/1     Running   0          51m
calico-node-wmbqv                          1/1     Running   0          51m
```



## **flannel

```sh
https://github.com/coreos/flannel 中推荐方法

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```



## *迁移镜像到本地harbor （可选 但推荐）

```sh
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

#查看镜像版本
cat kube-flannel.yml|grep image
        image: quay.io/coreos/flannel:v0.13.0-rc2
        image: quay.io/coreos/flannel:v0.13.0-rc2
#上传镜像到本地harbor
docker pull quay.io/coreos/flannel:v0.13.0-rc2
docker image tag quay.io/coreos/flannel:v0.13.0-rc2    hb.sp.com/flannel/flannel:v0.13.0-rc2
docker push hb.sp.com/flannel/flannel:v0.13.0-rc2 
#修改清单
sed -i "s@quay.io/coreos/flannel:v0.13.0-rc2@hb.sp.com/flannel/flannel:v0.13.0-rc2@g" kube-flannel.yml
cat kube-flannel.yml|grep image
        image: hb.sp.com/flannel/flannel:v0.13.0-rc2
        image: hb.sp.com/flannel/flannel:v0.13.0-rc2
```



## *部署

```sh
kubectl apply -f kube-flannel.yml
#验证
kubectl get pod -n kube-system -o wide
NAME                    READY   STATUS    RESTARTS   AGE   IP             NODE          NOMINATED NODE   READINESS GATES
kube-flannel-ds-7pfdp   1/1     Running   0          48s   192.168.1.71   k-m1.sp.com   <none>           <none>
kube-flannel-ds-hn6bf   1/1     Running   0          48s   192.168.1.82   k-n2.sp.com   <none>           <none>
kube-flannel-ds-vjr2k   1/1     Running   0          48s   192.168.1.81   k-n1.sp.com   <none>           <none>。
```

