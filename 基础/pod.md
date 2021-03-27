# pod重启策略
~~~ 
Always: 容器失效时，由kubelet自动重启
OnFailure: 容器终止运行且退出码不为0时，由kubelet自动重启
Never: 无论容器运行状态如何，kubelet都不会重启该容器
~~~
# liveness 
> 存活检测，检测不通过重启容器
# Readiness
> 检测不通过，流量被阻断，容器标记为不可用，不会重启容器
# pod健康检测
### 
> kubectl run busybox --image-busybox --dry-run-client -o yaml > demo.yaml
