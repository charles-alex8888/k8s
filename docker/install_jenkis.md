# docker-compose.yaml
~~~ bash
version: '3'
services:
  jenkins:
    image: jenkinsci/blueocean    #镜像名称
    container_name: jenkins    #指定容器名
    restart: always    #在容器退出时总是重启容器
    user: root    #指定用户                                
    network_mode: "host"    #网络模式（默认bridge）
    #ports:    #容器的端口映射到宿主机上（“:”前数字为宿主机端口，“:”后数字为容器端口）
    #  - "8080:8080"    #自定义宿主机端口8080
    #  - "5000:5000"
    environment:
      TZ: Asia/Shanghai    #指定容器运行所属时区
    volumes:
    - ./jenkins_home:/var/jenkins_home     
    - ./home:/home    #将容器的/home目录映射到宿主机上目录中的/data/jenkins/home子目录 
    - /var/run/docker.sock:/var/run/docker.sock    #Docker守护进程（Docker daemon）默认监听的Unix域套接字（Unix domain socket），容器中的进程可以通过它与Docker守护进程进行通信。简单来说容器使用宿主机docker命令

~~~
