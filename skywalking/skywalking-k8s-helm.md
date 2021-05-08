# skywalking-k8s

## 部署

```sh
git clone https://github.com/apache/skywalking-kubernetes
cd skywalking-kubernetes/chart/skywalking
#添加 所依赖的仓库
helm repo add elastic https://helm.elastic.co
#更新依赖  实际上就是把依赖的chart拖下来
helm dep up .
```

### 修改values.yaml

```yaml
#oap部分
oap:
  name: oap
  dynamicConfigEnabled: false
  image:
    repository: apache/skywalking-oap-server
    tag: 8.1.0-es7
    pullPolicy: IfNotPresent
  storageType: elasticsearch7
```

```yaml
#ui部分
ui:
  name: ui
  replicas: 1
  image:
    repository: apache/skywalking-ui
    tag: 8.1.0
    
    ...
  service:
    type: NodePort
    nodePort: 30018
    # clusterIP: None
    externalPort: 80
    internalPort: 8080
```

```yaml
#elasticsearch部分
elasticsearch:
  enabled: true
  config:               # For users of an existing elasticsearch cluster,takes effect when `elasticsearch.enabled` is false
    port:
      http: 9200
    host: elasticsearch # es service on kubernetes or host
    user: "elastic"         # [optional]
    password: "888666"     # [optional]
  clusterName: "elasticsearch"
  nodeGroup: "master"
...
  image: "docker.elastic.co/elasticsearch/elasticsearch"
  # imageTag: "6.8.6"
  imagePullPolicy: "IfNotPresent"
...
  volumeClaimTemplate:
    accessModes: [ "ReadWriteOnce" ]
    storageClassName: "pub-nfs-sc"
    resources:
      requests:
        storage: 10Gi

...
  persistence:
    enabled: true
    annotations: {}
```

```sh
#部署
kubectl create ns skywalking
helm install skywalking . -n skywalking  -f values.yaml
```

## 改造

```sh
#制作agent容器镜像
FROM alpine:3.8
ENV SKYWALKING_VERSION=8.1.0
ADD http://mirrors.tuna.tsinghua.edu.cn/apache/skywalking/${SKYWALKING_VERSION}/apache-skywalking-apm-${SKYWALKING_VERSION}.tar.gz /
RUN tar -zxvf /apache-skywalking-apm-${SKYWALKING_VERSION}.tar.gz && \
    mv apache-skywalking-apm-bin skywalking && \
    mv /skywalking/agent/optional-plugins/apm-trace-ignore-plugin* /skywalking/agent/plugins/ && \
    echo -e "\n# Ignore Path" >> /skywalking/agent/config/agent.config && \
    echo "# see https://github.com/apache/skywalking/blob/v8.1.0/docs/en/setup/service-agent/java-agent/agent-optional-plugins/trace-ignore-plugin.md" >> /skywalking/agent/config/agent.config && \
    echo 'trace.ignore_path=${SW_IGNORE_PATH:/health}' >> /skywalking/agent/config/agent.config
```

```yaml
#边车方式 实例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: svc-mall-admin
spec:
...
    spec:
      #以边车方式初始化容器 实际上就是复制agent 到共享挂在目录
      initContainers:
        - name: init-skywalking-agent
          image: 172.16.106.237/monitor/skywalking-agent:8.1.0
          command:
            - 'sh'
            - '-c'
            - 'set -ex;mkdir -p /vmskywalking/agent;cp -r /skywalking/agent/* /vmskywalking/agent;'
          volumeMounts:
            - mountPath: /vmskywalking/agent
              name: skywalking-agent
      containers:
        - image: 172.16.106.237/mall_repo/mall-admin:1.0
          imagePullPolicy: Always
          name: mall-admin
          ports:
            - containerPort: 8180
              protocol: TCP
          volumeMounts:
            - mountPath: /opt/skywalking/agent
              name: skywalking-agent
      #挂载一个临时目录 两个容器同时共享挂载
      volumes:
        - name: skywalking-agent
          emptyDir: {}
```

```sh
#dockerfile 
ENTRYPOINT ["java","-Dapp.id=svc-mall-admin","-javaagent:/opt/skywalking/agent/skywalking-agent.jar","-Dskywalking.agent.service_name=svc-mall-admin","-Dskywalking.collector.backend_service=my-skywalking-oap.skywalking.svc.cluster.local:11800","-jar","-Dspring.profiles.active=prod","-Djava.security.egd=file:/dev/./urandom","/app.jar"
# -Dapp.id=项目名称
# -javaagent:agent的jar包路径
# -Dskywalking.agent.service_name=项目名称
# -Dskywalking.collector.backend_service=oap地址和端口
```

## agent 参数

```jsx
 -javaagent:/lib/sky/agent/skywalking-agent.jar \
     -Dskywalking.agent.service_name=report_service_name \
     -Dskywalking.collector.backend_service=127.0.0.1:11800,127.0.0.1:11801  \
     -Dskywalking.logging.dir=/tmp/logs/ \
     -Dskywalking.logging.file_name=report_service_name .log
```

| 参数                                 | 说明                                     |
| ------------------------------------ | ---------------------------------------- |
| skywalking.agent.service_name        | 注册skywalking的服务名                   |
| skywalking.collector.backend_service | 后端主机名或者ip 加 端口，多个用逗号分隔 |
| skywalking.logging.dir               | 日志目录                                 |
| skywalking.logging.file_name         | 日志文件名                               |

下载地址    https://archive.apache.org/dist/skywalking/ 

https://archive.apache.org/dist/skywalking/8.4.0/apache-skywalking-apm-8.4.0.tar.gz

```sh
wget https://archive.apache.org/dist/skywalking/8.4.0/apache-skywalking-apm-8.4.0.tar.gz
tar xf apache-skywalking-apm-8.4.0.tar.gz

cat <<'EOF'>Dockerfile
FROM alpine:3.13.5
COPY ./apache-skywalking-apm-bin/agent /agent
EOF


docker build . -t .../sky-agent:8.4
```

