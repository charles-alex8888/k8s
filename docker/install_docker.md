# yum安装docker、docker-compose
~~~ bash
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

#yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum makecache fast && yum -y install docker-ce  
systemctl start docker
systemctl enable docker 
yum -y install epel-release
yum -y install python-pip 
yum -y install docker-compose

systemctl daemon-reload
systemctl restart docker
~~~
# 下载安装docker-compose
~~~ bash
curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
~~~
# 卸载docker
~~~ bash
yum -y remove docker-ce docker-ce-cli containerd.io

yum -y install bridge-utils
ifconfig docker0 down
brctl delbr docker0
~~~
