~~~ bash
#!/bin/bash
cat >/etc/sysctl.d/k8s.conf << 'EOF'
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.ip_forward = 1
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.netfilter.nf_conntrack_max = 2310720
fs.inotify.max_user_watches=89100
fs.may_detach_mounts = 1
fs.file-max = 52706963
fs.nr_open = 52706963
net.bridge.bridge-nf-call-arptables = 1
vm.swappiness = 0
vm.overcommit_memory=1
vm.panic_on_oom=0
EOF

echo 'ip_conntrack' >/etc/modules-load.d/k8s.conf && modprobe ip_conntrack && modprobe br_netfilter && sysctl -p /etc/sysctl.d/k8s.conf
echo '#!/bin/bash \n modprobe br_netfilter' > /etc/sysconfig/modules/br_netfilter.modules &&chmod 755 /etc/sysconfig/modules/br_netfilter.modules && source /etc/sysconfig/modules/br_netfilter.modules


wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.14.tgz 
tar xf docker-19.03.14.tgz && mv docker/* /usr/bin/ && rm -rf docker*.tgz
cat >/usr/lib/systemd/system/docker.service <<'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Environment="PATH=/opt/kube/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
mkdir -p /etc/docker/
cat >/etc/docker/daemon.json <<EOF
{
  "data-root": "/data/docker",
  "exec-opts": [ "native.cgroupdriver=cgroupfs" ],
  "registry-mirrors": [ "https://docker.mirrors.ustc.edu.cn", "http://hub-mirror.c.163.com" ],
  "insecure-registries": ["127.0.0.1/8"],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-opts": {
       "max-size": "100m",
       "max-file": "3"
   },
  "log-level": "warn",
  "log-opts": {
    "max-size": "15m",
    "max-file": "3"
    },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /data/docker/ && \
systemctl daemon-reload && systemctl enable docker && systemctl start docker

~~~
