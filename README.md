# debian 安装microk8s
~~~ bash
sudo apt update
sudo apt install snapd
sudo snap install core
snap install microk8s --classic

microk8s.enable dashboard dns ingress istio registry storage

# 终止
snap disable microk8s
# 卸载
snap remove microk8s
~~~
