# helm 安装
## 方法1
~~~ bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
~~~
## 方法2
~~~ bash
wget https://get.helm.sh/helm-v3.3.4-linux-amd64.tar.gz
tar xf helm-v3.3.4-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin
~~~

# 设置自动补全
~~~ bash
source <(helm completion bash)
echo 'source <(helm completion bash)' >> .bashrc
~~~

#  常用仓库
~~~ bash
# 微软仓库（推荐）
http://mirror.azure.cn/kubernetes/charts/
# 阿里云仓库
https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
# 官方仓库
https://hub.kubeapps.com/charts/incubator
# chart仓库
https://charts.helm.sh/stable
~~~ 

# 更新chart 仓库
> helm repo update

# 添加helm仓库
~~~ bash
helm repo add stable https://charts.helm.sh/stable
helm search repo stable
~~~ 

# 删除仓库
> helm repo remove stable

# 搜索chart
> helm search repo nginx

# 下载chart到本地
> helm pull google/nginx-ingress

# 部署
> helm install --name mariadb -n namespace_name stable/mariadb --version version -f value.yaml

# 查看helm 安装的资源列表
~~~ bash
helm list --all-namespaces
helm list
~~~

