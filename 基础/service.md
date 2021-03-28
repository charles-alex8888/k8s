# ***命令行***
### 创建svc
> kubectl expose deployment nginx --port=80 --target-port=80 service/nginx exposed
### 修改svc类型
> kubectl patch svc nginx -p '{"spec":{"type":"NodePort"}}'

# ***声明式***



# svc对接集群外资源
> subsets下配置为集群外的资源
~~~ yaml
kind: Service
apiVersion: v1
metadata:
  name:  mysvc
spec:
  selector:
    app:  nginx
  type:  ClusterIP
  ports:
  - port:  80
    protocol: TCP
    targetPort:  8080
  
---

kind: Endpoints
apiVersion: v1
metadata: 
  name: mysvc
subsets:
- addresses:
  - ip: 10.0.1.100
    nodeName: 10.0.1.100 
  ports:
  - port: 9999
    protocl: TCP
~~~

