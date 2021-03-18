---
title: 7NODE节点 kubelet
date: 2017-05-26 12:12:57
categories: 
- K8S部署
tags:
- K8S部署
---

#master 也需要安装 只是打不同标签

## **二进制文件 

```sh
wget https://dl.k8s.io/v1.15.2/kubernetes-node-linux-amd64.tar.gz
mkdir -p /opt/kube/bin/
tar xvf kubernetes-node-linux-amd64.tar.gz
mv kubernetes/node/bin/kube{let,-proxy}  /opt/kube/bin/
#分发
scp -rp /opt/kube/bin/kube{let,-proxy} k-n2:/opt/kube/bin/
scp -rp /opt/kube/bin/kube{let,-proxy} k-n1:/opt/kube/bin/
```



## ** kubelet-conf

```sh
cat >/etc/kubernetes/kubelet-conf.yml<<'EOF'
address: 0.0.0.0
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
cgroupDriver: systemd
cgroupsPerQOS: true
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
configMapAndSecretChangeDetectionStrategy: Watch
containerLogMaxFiles: 5
containerLogMaxSize: 10Mi
contentType: application/vnd.kubernetes.protobuf
cpuCFSQuota: true
cpuCFSQuotaPeriod: 100ms
cpuManagerPolicy: none
cpuManagerReconcilePeriod: 10s
enableControllerAttachDetach: true
enableDebuggingHandlers: true
enforceNodeAllocatable:
- pods
eventBurst: 10
eventRecordQPS: 5
evictionHard:
  imagefs.available: 15%
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
evictionPressureTransitionPeriod: 5m0s
failSwapOn: true
fileCheckFrequency: 20s
hairpinMode: promiscuous-bridge
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 20s
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
imageMinimumGCAge: 2m0s
iptablesDropBit: 15
iptablesMasqueradeBit: 14
kind: KubeletConfiguration
kubeAPIBurst: 10
kubeAPIQPS: 5
makeIPTablesUtilChains: true
maxOpenFiles: 1000000
maxPods: 110
nodeLeaseDurationSeconds: 40
nodeStatusReportFrequency: 1m0s
nodeStatusUpdateFrequency: 10s
oomScoreAdj: -999
podPidsLimit: -1
port: 10250
registryBurst: 10
registryPullQPS: 5
resolvConf: /etc/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 2m0s
serializeImagePulls: true
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 4h0m0s
syncFrequency: 1m0s
volumeStatsAggPeriod: 1m0s
EOF

**kubelet UnitFile
cat >/lib/systemd/system/kubelet.service<<'EOF'
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service
[Service]
ExecStart=/opt/kube/bin/kubelet \
  --bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig \
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \
  --config=/etc/kubernetes/kubelet-conf.yml \
  --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google_containers/pause-amd64:3.1 \
  --network-plugin=cni \
  --cni-conf-dir=/etc/cni/net.d \
  --cni-bin-dir=/opt/cni/bin \
  --cert-dir=/etc/kubernetes/pki \
  --cgroup-driver=cgroupfs \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=/data/kubelog/kubelet \
  --v=2
Restart=always
RestartSec=10s
[Install]
WantedBy=multi-user.target
EOF
```
##--pod-infra-container-imag 的pause 镜像 建议自己下载好 上传到内部harbor  这里填写内部harbor的地址

## **启动

```sh
mkdir -p /data/kubelog/kubelet /etc/kubernetes/manifests  /etc/cni/net.d
systemctl daemon-reload && systemctl enable kubelet && systemctl start kubelet

```

## **验证

```sh
kubectl get nodes
NAME          STATUS     ROLES    AGE    VERSION
k-n1.sp.com   NotReady   <none>   3s   	 v1.15.12
k-n2.sp.com   NotReady   <none>   3s     v1.15.12
**打标签声明role
##给master 打污点 和 role 标签
kubectl taint nodes k-m1.sp.com node-role.kubernetes.io/master="":NoSchedule
kubectl label node k-m1.sp.com node-role.kubernetes.io/master=""
##给node 打 role 标签
kubectl label node k-n1.sp.com node-role.kubernetes.io/node=""
kubectl label node k-n2.sp.com node-role.kubernetes.io/node=""
```

