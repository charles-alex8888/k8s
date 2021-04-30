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

# zsh下kubectl 命令补全
~~~ bash
source <(kubectl completion zsh)
echo 'source <(kubectl completion zsh)' >> ~/.zshrc
~~~


# 二进制安装 k8s 参考
https://github.com/easzlab/kubeasz

# Argo CD - Kubernetes的声明式GitOps持续交付
https://www.mikesay.com/ebooks/argocd/
