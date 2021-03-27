# ***pod重启策略***
~~~ 
Always: 容器失效时，由kubelet自动重启
OnFailure: 容器终止运行且退出码不为0时，由kubelet自动重启
Never: 无论容器运行状态如何，kubelet都不会重启该容器
~~~
# ***pod健康检测***
#### Liveness 
> 存活检测，检测不通过重启容器
~~~ yaml
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
~~~
#### Readiness
~~~ txt
检测不通过，流量被阻断，容器标记为不可用，不会重启容器
如果更新版本导致readiness检测不过，会新老版本同时存在，pod数量会超出replicas设定的数量（超35%）
~~~
~~~ yaml
        strategy:
          rollingUpdate:
            maxSurge: 35%
            maxUnavailable: 35%
          type: RollingUpdate
~~~
~~~ yaml
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
~~~
