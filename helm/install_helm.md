# helm 安装
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# 更新chart 仓库
helm repo update

# 添加helm仓库
helm repo add stable https://charts.helm.sh/stable
helm search repo stable
