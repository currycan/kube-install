# ansible-kubeadm

 使用 ansible 搭建生产级高可用集群, kubeadm 方式

## 1. 准备

### 1.1 安装 ansible

- Centos 7:

```bash
curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum install -y ansible
```

安装 nfs server:

```bash
yum install nfs-utils rpcbind -y
systemctl enable --now rpcbind.service
systemctl enable --now nfs.service
mkdir -p /nfs/data
chown nfsnobody:nfsnobody /nfs/data
echo "/nfs/data 10.10.10.0/24(rw,sync,no_root_squash)">>/etc/exports
echo "/nfs/data 127.0.0.1(rw,sync,no_root_squash)">>/etc/exports
exportfs -rv
showmount -e localhost
```
