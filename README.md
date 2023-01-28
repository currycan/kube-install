# ansible 安装 kubernetes

 使用 ansible 搭建生产级高可用集群, 同时支持二进制和 kubeadm 方式

## 1. 准备

- 安装 ansible
- 配置免密
- 挂载数据盘（可选）
- 配置 ansible hosts
- 准备离线文件

### 1.1 安装 ansible, 选取**第一个 master 节点**

- Centos 7:

```bash
curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum install -y ansible
```

### 1.2 配置免密

```bash
# Ed25519 算法, 更安全
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
# 或者传统 RSA 算法
ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa

ssh-copy-id $IPs #$IPs为所有节点地址包括自身，按照提示输入 yes 和 root 密码
```

### 1.3 挂载数据盘(可选)

安装 lvm

```bash
# Centos
yum -y install lvm2*
# Ubuntu
apt-get -y install lvm2*
```

参考: [初识LVM及ECS上LVM分区扩容-阿里云开发者社区](https://developer.aliyun.com/article/572204)

查看磁盘信息

```bash
$ lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda               8:0    0   40G  0 disk
├─sda1            8:1    0    1G  0 part /boot
└─sda2            8:2    0   39G  0 part
  ├─centos-root 253:0    0   35G  0 lvm  /
  └─centos-swap 253:1    0    4G  0 lvm  [SWAP]
sdb               8:16   0  100G  0 disk
sr0              11:0    1 1024M  0 rom
```

sdb 是一块新的数据盘, 创建一个 LVM 分区. fdisk的参数（n/p/1/回车/回车/t/8e/w）
注：8e代表是lvm的分区

```bash
DISK1=sdb
# 创建和管理LVM
fdisk /dev/${DISK1}
> n/p/1/回车/回车/t/8e/w
# 创建 PV
pvcreate /dev/${DISK1}1
# 创建 VG
vgcreate k8s /dev/${DISK1}1
# 创建 LV
lvcreate -L 10G -n download k8s
# lvcreate -l 100%VG -n download k8s
lvcreate -L 10G -n data k8s
# 格式化 LVM 分区
mkfs.xfs /dev/k8s/download
mkfs.xfs /dev/k8s/data
# 挂载 LVM 分区(/k8s_cache)
mkdir -p /k8s_cache
mkdir -p /var/lib/docker
mount /dev/k8s/download /k8s_cache/
mount /dev/k8s/data /var/lib/docker
echo "/dev/k8s/download    /k8s_cache     xfs    defaults        0 0" >>/etc/fstab
echo "/dev/k8s/data   /var/lib/docker    xfs    defaults        0 0" >>/etc/fstab
```

删除LVM

```bash
# 查看lvm
lvs
# 删除 lvm
lvremove /dev/k8s/data
```

### 1.4 配置 ansible hosts

根据集群各节点角色和属性参考[hosts](./inventory/hosts-cluster.example)配置

### 1.5 准备离线文件

```bash
kube_offline_version=1.26.0
curl -o /k8s_cache_${kube_offline_version}.tgz https://k8s-offline.oss-cn-shanghai.aliyuncs.com/k8s_cache_${kube_offline_version}.tgz
ansible all -m copy -a "src=/k8s_cache_${kube_offline_version}.tgz dest=/k8s_cache_${kube_offline_version}.tgz"
ansible all -m shell -a "rm -rf /k8s_cache"
ansible all -m shell -a "tar zxf /k8s_cache_${kube_offline_version}.tgz -C /"
```

第一个 master 节点（deploy 节点）

```bash
cp -f /k8s_cache/version.yml /etc/ansible/group_vars/all/version.yml
/usr/bin/lvscare care --vs 10.10.10.49:6443 --health-path /healthz --health-schem https --rs 172.22.0.7:6443 --rs 172.22.0.10:6443 --rs 172.22.0.17:6443 --interval 5 --mode link
```

## 2. 配置

本项目支持多种方式一键安装 kubernetes 集群：二进制安装和 kubeadm 安装，证书创建方式也支持多种：cfssl、openssl、kubeadm、kube-certs，满足多种个性化需求。

**默认使用 kube-certs 创建证书，kubeadm 搭建集群**。

具体组合如下：
binary:
  certs: kube-certs
  certs: kubeadm
  certs: openssl
  certs: cfssl
kubeadm:
  certs: kube-certs
  certs: kubeadm
  certs: openssl

## 3. 安装 nfs server

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
