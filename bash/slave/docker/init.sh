#!/bin/sh
pushd ${k8s_dir}/docker
#删除残留的docker
yum remove docker \
                  docker-common \
                  docker-selinux \
                  docker-engine
#下载docker
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.03.0.ce-1.el7.centos.x86_64.rpm

#下载docker-ce-selinux

wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-selinux-17.03.0.ce-1.el7.centos.noarch.rpm

#安装selinux 
yum -y install docker-ce-selinux-17.03.0.ce-1.el7.centos.noarch.rpm
#安装docker
yum -y install docker-ce-17.03.0.ce-1.el7.centos.x86_64.rpm
#开机自启动

cat > docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network.target

[Service]
Type=notify
EnvironmentFile=-/run/flannel/docker
ExecStart=/usr/bin/dockerd --log-level=error $DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

rm -f /usr/lib/systemd/system/docker.service
cp docker.service /usr/lib/systemd/system/
rm -f docker*



iptables -P FORWARD ACCEPT

echo "sleep 60 && /sbin/iptables -P FORWARD ACCEPT" >> /etc/rc.local

iptables -F 
iptables -X 
iptables -F -t nat 
iptables -X -t nat

systemctl daemon-reload
systemctl enable docker
systemctl start docker

popd
