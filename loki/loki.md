# LOKI

## 安装loki

```sh
#添加仓库
helm repo add loki https://grafana.github.io/loki/charts
helm repo update
```

```sh
#搜索
╰─➤  helm search repo loki 
NAME            CHART VERSION   APP VERSION     DESCRIPTION                                       
loki/loki       2.1.1           v2.0.0          DEPRECATED Loki: like Prometheus, but for logs.   
loki/loki-stack 2.1.2           v2.0.0          DEPRECATED Loki: like Prometheus, but for logs.   
loki/fluent-bit 2.0.2           v2.0.0          DEPRECATED Uses fluent-bit Loki go plugin for g...
loki/promtail   2.0.2           v2.0.0          DEPRECATED Responsible for gathering logs and s...
```

```sh
#下载包
helm pull loki/loki
```

```sh
#修改配置
tar xf loki-2.1.1.tgz
cd loki
vim values.yaml
```

```sh
#循环删除部分
  #这里是持久存储循环删除 也就是最多存储多长时间的数据
  table_manager:
    #retention_deletes_enabled: false
    retention_deletes_enabled: true
    #retention_period: 0s
    #注意文档说 这里如果是小时单位必须是168的倍数 168小时就是一个星期
    retention_period: 168h
```

```sh
#持久存储部分
persistence:
  #是否启用持久存储
  enabled: true
  #存储模式 这一定要与存储对应
  accessModes:
  - ReadWriteOnce
  #使用多大存储
  size: 10Gi
  annotations: {}
  # selector:
  #   matchLabels:
  #     app.kubernetes.io/name: loki
  # subPath: ""
  #调用pvc 作为持久存储
  existingClaim: loki-nfs-pvc
```

```sh
#事先创建pvc 以共 稍后部署loki 使用
vim  loki-pvc.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: loki-nfs-pvc
  namespace: loki
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
        storage: 5Gi
  storageClassName: pub-nfs-sc
#storageClassName 可以 使用kubectl get sc 来查看 自己使用什么sc资源
```

```sh
#创建名称空间
kubectl create ns loki
#创建pvc
kubectl apply -f loki-pvc.yaml
```

```sh
#检查pvc状态是否 bound
╰─➤  kubectl get pvc -n loki
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
loki-nfs-pvc   Bound    pvc-e8fd3029-62da-4356-a27a-c7c513f3c4d6   5Gi        RWO            pub-nfs-sc     13m
```

```sh
#安装loki并指定刚修改的values.yaml 文件 指定名称空间为loki
helm install loki  loki/loki -n loki -f values.yaml
```

```sh
#检查loki状态
╰─➤  kubectl get pod -n loki 
NAME     READY   STATUS    RESTARTS   AGE
loki-0   1/1     Running   0          14m
```

## 安装promtail

```sh
#搜索
╰─➤  helm search repo promtail
NAME            CHART VERSION   APP VERSION     DESCRIPTION                                       
loki/promtail   2.0.2           v2.0.0          DEPRECATED Responsible for gathering logs and s...
```

```sh
#安装 并指定 名称空间 以及 loki的service
helm install promtail loki/promtail -n loki  --set "loki.serviceName=loki"
```

```sh
#检查promtail状态
╰─➤  kubectl get pod -n loki                    
NAME             READY   STATUS    RESTARTS   AGE
loki-0           1/1     Running   0          26m
promtail-c6rd4   1/1     Running   0          2m57s
promtail-j62gk   1/1     Running   0          2m57s
promtail-k6sw7   1/1     Running   0          2m57s
promtail-p46df   1/1     Running   0          2m57s
```

## 部署grafana

- 因集群使用1.18 而helm官方仓库版本过低 导致新的api群组不被支持 所以这里采用手动部署 
- 如果你集群中有kube-prometheus之类的组件 并且其中已经有了grafana 直接使用即可 无需部署grafana

```sh
#准备pvc
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: grafana-nfs-pvc
  namespace: loki
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  #引用sc资源  
  storageClassName: pub-nfs-sc
```

```sh
#部署grafana
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana-loki
  namespace: loki
  labels:
    app: grafana-loki
spec:
  replicas: 1
  template:
    metadata:
      name: grafana-loki
      labels:
        app: grafana-loki
    spec:
      containers:
        - name: grafana-loki
          image: grafana/grafana:7.3.10
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 3000
          env:
            - name: GF_SECURITY_ADMIN_USER
              value: admin
            - name: GF_SECURITY_ADMIN_PASSWORD
              value: admin888
          readinessProbe:
            failureThreshold: 10
            httpGet:
              path: /api/health
              port: 3000
              scheme: HTTP
            initialDelaySeconds: 60
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 30
          livenessProbe:
              failureThreshold: 3
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 1
              httpGet:
                path: /api/health
                port: 3000
                scheme: HTTP
          resources:
            limits:
              cpu: 150m
              memory: 256Mi
            requests:
              cpu: 150m
              memory: 256Mi
          volumeMounts:
            - mountPath: /var/lib/grafana
              name: nfs
      volumes:
        - name: nfs
          persistentVolumeClaim:
            claimName: grafana-nfs-pvc
      restartPolicy: Always
  selector:
    matchLabels:
      app: grafana-loki
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-loki
spec:
  selector:
    app: grafana-loki
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30010
  type: NodePort
```

```sh
#验证pod
╰─➤  kubectl get pod -n loki
NAME                            READY   STATUS    RESTARTS   AGE
grafana-loki-595bc66bd4-sj8lb   1/1     Running   0          17m
loki-0                          1/1     Running   0          122m
promtail-c6rd4                  1/1     Running   0          99m
promtail-j62gk                  1/1     Running   0          99m
promtail-k6sw7                  1/1     Running   0          99m
promtail-p46df                  1/1     Running   0          99m
```

```sh
#验证svc
╰─➤  kubectl get svc -n loki
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
grafana-loki    NodePort    10.68.194.51    <none>        3000:30010/TCP   10m
loki            ClusterIP   10.68.187.228   <none>        3100/TCP         124m
loki-headless   ClusterIP   None            <none>        3100/TCP         124m
```

## 访问grafana

- 用户名密码 见 上面的清单 env字段

![image-20210319171228337](loki/image-20210319171228337.png)

![image-20210319171330355](loki/image-20210319171330355.png)

![image-20210319171406964](loki/image-20210319171406964.png)

![image-20210319171431088](loki/image-20210319171431088.png)

![image-20210319171705207](loki/image-20210319171705207.png)

![image-20210319171811781](loki/image-20210319171811781.png)

![image-20210319171922259](loki/image-20210319171922259.png)ls
