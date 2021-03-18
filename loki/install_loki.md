# 创建名称空间
> kubectl create ns loki

# 增加源并更新
~~~ bash
helm repo add loki https://grafana.github.io/loki/charts
helm upgrade --install loki --namespace=loki loki/loki-stack
helm repo update
~~~
# 拉取 chart
~~~ bash
helm fetch loki/loki-stack --untar --untardir .
cd loki-stack
~~~ 
> 将 values.yaml 中的 grafana.enable 改成 true, 因为我们需要部署 grafana
# 生成 k8s 配置
~~~ bash
helm template loki . > loki.yaml
~~~ 
# 部署
> kubectl apply -f loki.yaml


## 输出 grafana 登录密码
> kubectl get secret --namespace default loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
