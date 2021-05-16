####  准备配置文件 redis-cluster.tmpl

~~~
port ${PORT}
requirepass 1234
masterauth 1234
protected-mode no
daemonize no
appendonly yes
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 15000
cluster-announce-ip 192.168.10.11
cluster-announce-port ${PORT}
cluster-announce-bus-port 1${PORT}
~~~

#### 修改配置

~~~
for port in `seq 6371 6376`; do \
  mkdir -p ${port}/conf \
  && PORT=${port} envsubst < redis-cluster.tmpl > ${port}/conf/redis.conf \
  && mkdir -p ${port}/data;\
done

~~~



#### 准备docker-compose.yaml

~~~
# 描述 Compose 文件的版本信息
version: "3.3"

# 定义服务，可以多个
services:
  redis-6371: # 服务名称
    image: redis # 创建容器时所需的镜像
    container_name: redis-6371 # 容器名称
    restart: always # 容器总是重新启动
    network_mode: "host" # host 网络模式
    volumes: # 数据卷，目录挂载
      - ./6371/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./6371/data:/data
    command: redis-server /usr/local/etc/redis/redis.conf # 覆盖容器启动后默认执行的命令

  redis-6372:
    image: redis
    container_name: redis-6372
    network_mode: "host"
    volumes:
      - ./6372/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./6372/data:/data
    command: redis-server /usr/local/etc/redis/redis.conf

  redis-6373:
    image: redis
    container_name: redis-6373
    network_mode: "host"
    volumes:
      - ./6373/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./6373/data:/data
    command: redis-server /usr/local/etc/redis/redis.conf

  redis-6374:
    image: redis 
    container_name: redis-6374
    restart: always 
    network_mode: "host" 
    volumes: 
      - ./6374/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./6374/data:/data
    command: redis-server /usr/local/etc/redis/redis.conf 

  redis-6375:
    image: redis
    container_name: redis-6375
    network_mode: "host"
    volumes:
      - ./6375/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./6375/data:/data
    command: redis-server /usr/local/etc/redis/redis.conf

  redis-6376:
    image: redis
    container_name: redis-6376
    network_mode: "host"
    volumes:
      - ./6376/conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./6376/data:/data
    command: redis-server /usr/local/etc/redis/redis.conf
~~~

启动后进入任意一个容器执行以下命令

~~~
# 启动
> docker-compose up -d
# 进入容器
> docker exec -it {containerid} bash
# 创建集群
> redis-cli -a 1234 --cluster create 192.168.10.11:6371 192.168.10.11:6372 192.168.10.11:6373 192.168.10.11:6374 192.168.10.11:6375 192.168.10.11:6376 --cluster-replicas 1
# 查看集群状态
> redis-cli -a 1234 --cluster check 192.168.10.11:6375
# 连接集群
> redis-cli -c -h 192.168.10.11 -p 6379
> cluster info
> cluster nodes
~~~





