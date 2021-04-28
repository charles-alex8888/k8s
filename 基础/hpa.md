# 前提是dns和metrics-server服务正常运行
~~~ bash
			 resources:
			 	 limits:
			 	   cpu: "1"
			 	   memory: 2Gi
			 	 requests:
			 	   cpu: "1"
			 	   memory: 2Gi
~~~

# 测试hap自动水平伸缩
~~~ bash
kubectl run -it --rm busy box --image=busybpx -- sh
while :;do wget -q -O- http://web; done
~~~
