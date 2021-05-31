# kubectl 
## basic command (beginner)
### create
#### configmap
#### namespace
#### deployment
#### quota
#### secrete
#### service
#### serviceaccount
#### -f object.yaml/json
### expose
#### pod
#### service
#### replicationcontroller
#### deployment
#### replicaset
### run
#### --images
#### --replicas
#### --command
#### --<arg1> <arg2> ... <argN>
#### --restart
#### --env
### set
#### image
#### resources
## basic command (intermediate)
### get
### explain
### edit
### delete
## deploy command
### rollout
#### history
#### pause
#### resume
#### status
#### undo
### rolling-update
#### --image
#### --rollback
### scale
### autoscale
## cluster management commands
### certificate
#### approve
#### deny
### cluster-info
#### dump
### top
#### node
#### pod
### cordon
### uncordon
### drain
#### --delete-local-data=false
#### --force=false
#### --grace-period=-1
#### --ignore-daemonsets=false
#### -timeout=0s
### taint
## options
## settings commands
### label
### annotate
### completion
## troubleshooting and debugging commands
### describe
### logs
### attach
### exec
### port-forward
### proxy
### cp
## advanced commands
### patch
### replace
### convert
### apply
## other commands
### api-versions
### config
### help
### version

# resources types
## podtemplates
## horizontalpodautoscalers(hpa)
## podsecuritypolicies(psp)
## daemonsets(ds)
## pods(po)
## serviceaccounts(sa)
## secrets
## persistentvolumes(pv)
## componentstatuses(cs)
## networkpolicies
## deployments(deploy)
## storageclasses
## statefulsets
## persistentvolumeclaimes(pvc)
## nodes(no)
## services(svc)
## clusters(svc)
## events(ev)
## resourcequotas(quota)
## configmaps(cm)
## repliationcontrollers(rc)
## thirdpartyresources
## imgresses(ing)
## limitranges(limits)
## namespaces(ns)
## jobs
## replicasets(rs)
## endpoints(ep)
