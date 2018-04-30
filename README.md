# salt-kubernetes
SaltStack自动化部署Kubernetes v1.9.3版本（支持TLS 双向认证、RBAC 授权、Flannel网络、ETCD集群等）

## 版本明细：Release-v1.0

- 测试通过系统：CentOS 7.4
- salt-ssh: 2017.7.4
- Kubernetes： v1.9.3
- Etcd: v3.3.1
- Docker: 17.12.1-ce
- Flannel： v0.10.0
- CNI-Plugins： v0.7.0
建议部署节点：最少三个节点，请配置好主机名解析（必备）

## 架构介绍

1. 使用Salt Grains进行角色定义，增加灵活性。
2. 使用Salt Pillar进行配置项管理，保证安全性。
3. 使用Salt SSH执行状态，不需要安装Agent，保证通用性。
4. 使用Kubernetes当前稳定版本v1.9.3，保证稳定性。

## 技术交流QQ群（加群请备注来源于Github）：
- 自动化运维工程师：439084446
- 云计算与容器架构师：252370310
- 运维开发工程师：399033250

# 使用手册
## 0.系统初始化

1. 设置主机名！！！
2. 设置/etc/hosts保证主机名能够解析
3. 关闭SELinux和防火墙!!!!!!!

## 1.设置部署节点到其它所有节点的SSH免密码登录（包括本机）
```
[root@linux-node1 ~]# ssh-keygen -t rsa
[root@linux-node1 ~]# ssh-copy-id linux-node1
[root@linux-node1 ~]# ssh-copy-id linux-node2
[root@linux-node1 ~]# ssh-copy-id linux-node3
```

## 2.安装Salt-SSH并克隆本项目代码。

2.1 安装Salt SSH
```
[root@linux-node1 ~]# yum install https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el7.noarch.rpm 
[root@linux-node1 ~]# yum install -y salt-ssh
```

2.2 获取本项目代码，并放置在/srv目录
```
[root@linux-node1 ~]# git clone https://github.com/unixhot/salt-kubernetes.git
[root@linux-node1 srv]# cd salt-kubernetes/
[root@linux-node1 srv]# mv * /srv/
[root@linux-node1 srv]# cd /srv/
[root@linux-node1 srv]# cp roster /etc/salt/roster
[root@linux-node1 srv]# cp master /etc/salt/master
```

2.4 下载二进制文件，也可以自行官方下载，为了方便国内用户访问，请在百度云盘下载。
下载完成后，将文件移动到/srv/salt/k8s/目录下，并解压
Kubernetes二进制文件下载地址： https://pan.baidu.com/s/1zs8sCouDeCQJ9lghH1BPiw

```
[root@linux-node1 ~]# cd /srv/salt/k8s/
[root@linux-node1 k8s]# unzip k8s-v1.9.3.zip 
[root@linux-node1 k8s]# ls -l files/
total 0
drwxr-xr-x 2 root root  94 Mar 28 00:33 cfssl-1.2
drwxrwxr-x 2 root root 195 Mar 27 23:15 cni-plugins-amd64-v0.7.0
drwxr-xr-x 2 root root  33 Mar 28 00:33 etcd-v3.3.1-linux-amd64
drwxr-xr-x 2 root root  47 Mar 28 12:05 flannel-v0.10.0-linux-amd64
drwxr-xr-x 3 root root  17 Mar 28 00:47 k8s-v1.9.3
```

## 3.Salt SSH管理的机器以及角色分配

- k8s-role: 用来设置K8S的角色
- etcd-role: 用来设置etcd的角色，如果只需要部署一个etcd，只需要在一台机器上设置即可
- etcd-name: 如果对一台机器设置了etcd-role就必须设置etcd-name

```
[root@linux-node1 ~]# vim /etc/salt/roster 
linux-node1:
  host: 192.168.56.20
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: master
      etcd-role: node
      etcd-name: etcd-node1

linux-node2:
  host: 192.168.56.21
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
      etcd-role: node
      etcd-name: etcd-node2

linux-node3:
  host: 192.168.56.22
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
      etcd-role: node
      etcd-name: etcd-node3
```

## 4.修改对应的配置参数，本项目使用Salt Pillar保存配置
```
[root@linux-node1 ~]# vim /srv/pillar/k8s.sls
#设置Master的IP地址(必须修改)
MASTER_IP: "192.168.56.20"

#设置ETCD集群访问地址（必须修改）
ETCD_ENDPOINTS: "https://192.168.56.20:2379,https://192.168.56.21:2379,https://192.168.56.22:2379"

#设置ETCD集群初始化列表（必须修改）
ETCD_CLUSTER: "etcd-node1=https://192.168.56.20:2380,etcd-node2=https://192.168.56.21:2380,etcd-node3=https://192.168.56.22:2380"

#通过Grains FQDN自动获取本机IP地址，请注意保证主机名解析到本机IP地址
NODE_IP: {{ grains['ipv4'][-1] }}


#设置BOOTSTARP的TOKEN，可以自己生成
BOOTSTRAP_TOKEN: "ad6d5bb607a186796d8861557df0d17f"

#配置Service IP地址段
SERVICE_CIDR: "10.1.0.0/16"

#Kubernetes服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_KUBERNETES_SVC_IP: "10.1.0.1"

#Kubernetes DNS 服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_DNS_SVC_IP: "10.1.0.2"

#设置Node Port的端口范围
NODE_PORT_RANGE: "20000-40000"

#设置POD的IP地址段
POD_CIDR: "10.2.0.0/16"

#设置集群的DNS域名
CLUSTER_DNS_DOMAIN: "cluster.local."

```

## 5.执行SaltStack状态
```
测试Salt SSH联通性
[root@linux-node1 ~]# salt-ssh '*' test.ping

执行高级状态，会根据定义的角色再对应的机器部署对应的服务

5.1 部署Etcd，由于Etcd是基础组建，需要先部署，目标为部署etcd的节点。
[root@linux-node1 ~]# salt-ssh -L 'linux-node1,linux-node2,linux-node3' state.sls k8s.etcd

5.2 部署K8S集群
[root@linux-node1 ~]# salt-ssh '*' state.highstate
```
由于包比较大，这里执行时间较长，5分钟+，如果执行有失败可以再次执行即可！

## 6.测试Kubernetes安装（请新打开一个窗口，保证环境变量生效！）
```
[root@k8s-node1 ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-0               Healthy   {"health":"true"}   
etcd-2               Healthy   {"health":"true"}   
etcd-1               Healthy   {"health":"true"}   
[root@k8s-node1 ~]# kubectl get node
NAME            STATUS    ROLES     AGE       VERSION
192.168.56.21   Ready     <none>    1m        v1.9.3
192.168.56.22   Ready     <none>    1m        v1.9.3
```
## 7.测试Kubernetes集群和Flannel网络
```
[root@linux-node1 ~]# kubectl run net-test --image=alpine --replicas=2 sleep 360000
deployment "net-test" created
需要等待拉取镜像，可能稍有的慢，请等待。
[root@linux-node1 ~]# kubectl get pod -o wide
NAME                        READY     STATUS    RESTARTS   AGE       IP          NODE
net-test-74f45db489-9hr74   1/1       Running   0          48s       10.2.43.2   192.168.56.22
net-test-74f45db489-rkfjs   1/1       Running   0          48s       10.2.59.2   192.168.56.21

测试联通性
[root@linux-node1 ~]# ping -c 1 10.2.43.2
PING 10.2.43.2 (10.2.43.2) 56(84) bytes of data.
64 bytes from 10.2.43.2: icmp_seq=1 ttl=61 time=3.11 ms

--- 10.2.43.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 3.114/3.114/3.114/0.000 ms
[root@linux-node1 ~]# ping -c 1 10.2.59.2
PING 10.2.59.2 (10.2.59.2) 56(84) bytes of data.
64 bytes from 10.2.59.2: icmp_seq=1 ttl=61 time=1.23 ms

--- 10.2.59.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.230/1.230/1.230/0.000 ms
```
## 7.如何新增Kubernetes节点

- 1.设置SSH无密码登录
- 2.在/etc/salt/roster里面，增加对应的机器
- 3.执行SaltStack状态salt-ssh '*' state.highstate。
```
[root@linux-node1 ~]# vim /etc/salt/roster 
linux-node4:
  host: 192.168.56.23
  user: root
  priv: /root/.ssh/id_rsa
  minion_opts:
    grains:
      k8s-role: node
[root@linux-node1 ~]# salt-ssh '*' state.highstate
```

注意：不要相信自己，要相信电脑！！！
