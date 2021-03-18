---
title: 4ETCD部署
date: 2017-05-26 12:12:57
categories: 
- K8S部署
tags:
- K8S部署
---

## **下载etcd 二进制文件

```
wget https://github.com/coreos/etcd/releases/download/v3.3.7/etcd-v3.3.7-linux-amd64.tar.gz
tar xf etcd-v3.3.7-linux-amd64.tar.gz
```



## **分发二进制文件到各个etcd节点

```
scp -rp etcd-v3.3.7-linux-amd64 k-n1:/usr/local/etcd

echo 'export PATH=/usr/local/etcd/:$PATH' >  /etc/profile.d/etcd.sh && source /etc/profile.d/etcd.sh
```



## **制作ETCD  unitfile 模板 所有etcd节点执行

```
cat >/usr/lib/systemd/system/etcd.service <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos
[Service]
Type=notify
WorkingDirectory=/usr/local/etcd
ExecStart=/usr/local/etcd/etcd \\
    --data-dir=/data/etcd \\
    --name ##NODE_NAME## \\
    --cert-file=/etc/kubernetes/pki/etcd/server.crt \\
    --key-file=/etc/kubernetes/pki/etcd/server.key \\
    --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt \\
    --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt \\
    --peer-key-file=/etc/kubernetes/pki/etcd/peer.key \\
    --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt \\
    --peer-client-cert-auth \\
    --client-cert-auth \\
    --listen-peer-urls=https://##NODE_IP##:2380 \\
    --initial-advertise-peer-urls=https://##NODE_IP##:2380 \\
    --listen-client-urls=https://##NODE_IP##:2379,http://127.0.0.1:2379\\
    --advertise-client-urls=https://##NODE_IP##:2379 \\
    --initial-cluster-token=etcd-cluster-0 \\
    --initial-cluster=etcd01=https://192.168.1.71:2380,etcd02=https://192.168.1.81:2380,etcd03=https://192.168.1.82:2380 \\
    --initial-cluster-state=new
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF
```


#注：
##WorkingDirectory 、 --data-dir ：指定工作目录和数据目录为/opt/lib/etcd ，需在启动服务前创建这个目录；
#--name ：指定节点名称，当 --initial-cluster-state 值为 new 时， --name 的参数值必须位于 --initial-cluster 列表中；
#--cert-file 、 --key-file ：etcd server 与 client 通信时使用的证书和私钥；
#--trusted-ca-file ：签名 client 证书的 CA 证书，用于验证 client 证书；
#--peer-cert-file 、 --peer-key-file ：etcd 与 peer 通信使用的证书和私钥；
#--peer-trusted-ca-file ：签名 peer 证书的 CA 证书，用于验证 peer 证书

## **各个ETCD 替换模板内容

```
#不同节点替换不同名称和ip
sed -i 's%##NODE_NAME##%etcd01%g' /usr/lib/systemd/system/etcd.service && sed -i 's%##NODE_IP##%192.168.1.71%g' /usr/lib/systemd/system/etcd.service 
sed -i 's%##NODE_NAME##%etcd02%g' /usr/lib/systemd/system/etcd.service && sed -i 's%##NODE_IP##%192.168.1.81%g' /usr/lib/systemd/system/etcd.service
sed -i 's%##NODE_NAME##%etcd03%g' /usr/lib/systemd/system/etcd.service && sed -i 's%##NODE_IP##%192.168.1.82%g' /usr/lib/systemd/system/etcd.service
```



## **启动

```
#数据目录 权限
 mkdir -p /data/etcd 

#启动
systemctl daemon-reload && systemctl enable etcd && systemctl start etcd
```



## **验证集群

```
etcdctl --cert-file /etc/kubernetes/pki/etcd/healthcheck-client.crt \
--key-file /etc/kubernetes/pki/etcd/healthcheck-client.key \
--ca-file /etc/kubernetes/pki/etcd/ca.crt \
--endpoints="https://192.168.1.71:2379,https://192.168.1.81:2379,https://192.168.1.82:2379"  \
cluster-health

member 68afffba56612fd is healthy: got healthy result from https://192.168.1.71:2379
member e42b05792291d17 is healthy: got healthy result from https://192.168.1.81:2379
member e10fc861b3b13bc0 is healthy: got healthy result from https://192.168.1.82:2379
cluster is healthy
```

