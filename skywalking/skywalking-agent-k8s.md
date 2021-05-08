

# agent原理流程

- 制作docker镜像并上传  作用是作为初始化容器 复制到主容器
- 修改原来的业务dockerfile 使得 启动jar包过程 使用env 带入javaagent 配置
- 修改清单 添加初始化容器 
  -  添加公共挂在卷 
  - 初始化容器 与主容器 同时挂载公共挂在卷
  - 传入env 参数 使得javaagent配置成功调用

# agent 参数

```jsx
 -javaagent:/lib/sky/agent/skywalking-agent.jar \
     -Dskywalking.agent.service_name=report_service_name \
     -Dskywalking.collector.backend_service=127.0.0.1:11800,127.0.0.1:11801  \
     -Dskywalking.logging.dir=/tmp/logs/ \
     -Dskywalking.logging.file_name=report_service_name .log
或
-javaagent:/sidcar/agent/skywalking-agent.jar=agent.service_name=[服务名称],collector.backend_service=[oap地址]:[端口正常是11800]
#推荐第二种方式
```

| 参数                                 | 说明                                     |
| ------------------------------------ | ---------------------------------------- |
| skywalking.agent.service_name        | 注册skywalking的服务名                   |
| skywalking.collector.backend_service | 后端主机名或者ip 加 端口，多个用逗号分隔 |
| skywalking.logging.dir               | 日志目录                                 |
| skywalking.logging.file_name         | 日志文件名                               |

# 制作agent镜像 作为初始化容器

- 下载地址    https://archive.apache.org/dist/skywalking/ 
- https://archive.apache.org/dist/skywalking/8.4.0/apache-skywalking-apm-8.4.0.tar.gz
- 注意版本 尽量与 oap版本一致

```sh
wget https://archive.apache.org/dist/skywalking/8.4.0/apache-skywalking-apm-8.4.0.tar.gz
tar xf apache-skywalking-apm-8.4.0.tar.gz

cat <<'EOF'>Dockerfile
FROM alpine:3.13.5
COPY ./apache-skywalking-apm-bin/agent /agent
EOF

docker build . -t .../sky-agent:8.4
```

# 修改清单添加javaagent

```yaml
apiVersion: apps/v1
kind: Deployment
...
...
    spec:
      imagePullSecrets:
        - name: images-registry-id
      #定义初始化容器
      initContainers:
        - name: sky-agent
          image: image-registry-registry-vpc.cn-hongkong.cr.aliyuncs.com/ns/sky-agent:8.4
          imagePullPolicy: IfNotPresent
          #初始化实际上就是复制agent代理程序目录到公共存储卷，使得主容器也可以直接启动javaagent
          command: ["sh", "-c", "cp -r /agent /sidcar"]
          volumeMounts:
            - mountPath: /sidcar
              name: sidcar
      containers:
        - name: admin-backend-prod
          image: $REGISTRY/$DOCKERHUB_NAMESPACE/$APP_NAME:PROD-$BUILD_NUMBER
...
          env:
          #这里以环境变量方式 传入 java 参数 前提是 你的镜像中启动java的时候 调用了此环境变量 如果没有 就需要修改dockerfile
            - name: JAVA_AGENT
              value: "-javaagent:/sidcar/agent/skywalking-agent.jar=agent.service_name=$APP_NAME,collector.backend_service=skywalking-oap.skywalking.svc:11800"
...
...
          volumeMounts:
            - mountPath: /sidcar
              name: sidcar
      #定义存储卷为临时目录 此目录pod 重启后 会消失 
      #此存储卷 为 init 初始化容器 与 主容器 同时挂载 使得 agent 成功复制到主容器 
      volumes:
        - name: sidcar
          emptyDir: {}
```

