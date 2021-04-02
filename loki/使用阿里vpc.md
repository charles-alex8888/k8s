# 获取sc
> kubectl get sc | grep default

# 创建vpc
~~~ yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: loki-grafana-pvc
  namespace: loki
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: alicloud-disk-efficiency
  resources:
    requests:
      storage: 20Gi
~~~
> kubectl apply -f pvc.yaml

# grafana的pod增加安全上线文
~~~ yaml
    spec:
      securityContext:
        #卷中创建的任何文件都将是此组ID
        fsGroup: 0
        #所有进程都以用户ID运行
        runAsUser: 0
~~~ 
