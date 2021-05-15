~~~ bash
# 创建文件
mkdir 700{1..6}/data

# docker-compose.yaml
version: '3'

services:
 redis1:
  image: publicisworldwide/redis-cluster
  network_mode: host
  restart: always
  volumes:
   - ./7001/data:/data
  environment:
   - REDIS_PORT=7001

 redis2:
  image: publicisworldwide/redis-cluster
  network_mode: host
  restart: always
  volumes:
   - ./7002/data:/data
  environment:
   - REDIS_PORT=7002

 redis3:
  image: publicisworldwide/redis-cluster
  network_mode: host
  restart: always
  volumes:
   - ./7003/data:/data
  environment:
   - REDIS_PORT=7003

 redis4:
  image: publicisworldwide/redis-cluster
  network_mode: host
  restart: always
  volumes:
   - ./7004/data:/data
  environment:
   - REDIS_PORT=7004

 redis5:
  image: publicisworldwide/redis-cluster
  network_mode: host
  restart: always
  volumes:
   - ./7005/data:/data
  environment:
   - REDIS_PORT=7005

 redis6:
  image: publicisworldwide/redis-cluster
  network_mode: host
  restart: always
  volumes:
   - ./7006/data:/data
  environment:
   - REDIS_PORT=7006


# 进入任意一个容器配置集群
redis-cli --cluster create  172.16.200.79:7001  172.16.200.79:7002  172.16.200.79:7003  172.16.200.79:7004  172.16.200.79:7005  172.16.200.79:7006 --cluster-replicas 1

# 检查集群状态
redis-cli -c -h 172.16.200.79 -p 7001 
> cluster info
> cluster nodes

redis-cli --cluster check 172.16.200.79:7001
~~~
