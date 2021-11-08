#! /bin/env bash

set -eu

BASE_DIR=/k8s_cache
BINARY_DIR=${BASE_DIR}/binary
IMAGE_DIR=${BASE_DIR}/images
KERNEL_RPM_DIR=${BASE_DIR}/kernel
CHRONY_RPM_DIR=${BASE_DIR}/chrony
DEPENDENCE_RPM_DIR=${BASE_DIR}/dependence
CONTIANERD_RPM_DIR=${BASE_DIR}/containerd
DOCKER_RPM_DIR=${BASE_DIR}/docker
KUBERNETES_RPM_DIR=${BASE_DIR}/kubernetes

KUBERNETES_VERSION="1.22.3"
COREDNS_VERSION="1.8.0"

function create_dir (){
    mkdir -p \
        ${KERNEL_RPM_DIR} \
        ${CHRONY_RPM_DIR} \
        ${DEPENDENCE_RPM_DIR} \
        ${CONTIANERD_RPM_DIR} \
        ${DOCKER_RPM_DIR} \
        ${KUBERNETES_RPM_DIR} \
        ${IMAGE_DIR}
}

function config_yum_repo () {
    # kernel
    cat > /etc/yum.repos.d/linux-kernel.repo <<EOF
[kernel-longterm-4.19]
name=kernel-longterm-4.19
baseurl=https://copr-be.cloud.fedoraproject.org/results/kwizart/kernel-longterm-4.19/epel-7-x86_64/
enabled=1
gpgcheck=0
EOF
    # kubernetes
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
}

function download_kernel_rpm (){
    yum install -y linux-firmware perl-interpreter
    yum --disablerepo="*" --enablerepo=kernel-longterm-4.19 install -y --downloadonly --downloaddir=${KERNEL_RPM_DIR} \
    kernel-longterm \
    kernel-longterm-core \
    kernel-longterm-devel \
    kernel-longterm-modules \
    kernel-longterm-modules-extra \
    kernel-longterm-cross-headers
}

function download_chrony_rpm (){
    yum install -y --downloadonly --downloaddir=${CHRONY_RPM_DIR} chrony
}

function download_dependence_rpm (){
    yum install -y --downloadonly --downloaddir=${DEPENDENCE_RPM_DIR} \
        conntrack \
        conntrack-tools \
        psmisc \
        nfs-utils \
        iscsi-initiator-utils \
        jq \
        socat \
        bash-completion \
        rsync \
        ipset \
        ipvsadm \
        tree \
        git \
        systemd-devel \
        systemd-libs \
        libseccomp \
        libseccomp-devel \
        device-mapper-libs \
        iotop \
        htop \
        net-tools \
        sysstat \
        device-mapper-persistent-data \
        lvm2 \
        curl \
        yum-utils \
        nc \
        nmap-ncat \
        unzip \
        tar \
        btrfs-progs \
        btrfs-progs-devel \
        util-linux \
        libselinux-python \
        wget \
        audit \
        glib2-devel \
        irqbalance
}

function download_container_runtime_rpm (){
    yum install -y yum-utils
    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum install -y --downloadonly --downloaddir=${CONTIANERD_RPM_DIR} containerd.io
    yum install -y --downloadonly --downloaddir=${DOCKER_RPM_DIR} docker-ce docker-ce-cli containerd.io
}

function download_containerd_binary (){
    # containerd
    if [ ! -d ${BINARY_DIR}/containerd ];then
        cd /tmp
        containerd_version=`curl -sSf https://github.com/containerd/containerd/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1`
        curl -fSLO https://github.com/containerd/containerd/releases/download/${containerd_version}/cri-containerd-cni-${containerd_version:1}-linux-amd64.tar.gz
        mkdir -p ${BINARY_DIR}/containerd
        tar zxvf cri-containerd-cni-${containerd_version:1}-linux-amd64.tar.gz -C ${BINARY_DIR}/containerd
        rm -rf ${BINARY_DIR}/containerd/opt/containerd
    fi
    # crictl
    if [ ! -f ${BINARY_DIR}/crictl ];then
        cd /tmp
        crictl_version=`curl -sSf https://github.com/kubernetes-sigs/cri-tools/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1`
        curl -fSLO https://github.com/kubernetes-sigs/cri-tools/releases/download/${crictl_version}/crictl-${crictl_version}-linux-amd64.tar.gz
        mkdir -p ${BINARY_DIR}/crictl
        tar zxvf crictl-${crictl_version}-linux-amd64.tar.gz -C ${BINARY_DIR}/crictl
    fi
}

function download_etcd_binary (){
    if [ ! -d ${BINARY_DIR}/etcd ];then
        cd /tmp
        etcd_version=`curl -sSf https://github.com/etcd-io/etcd/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1`
        curl -fSLO https://github.com/etcd-io/etcd/releases/download/${etcd_version}/etcd-${etcd_version}-linux-amd64.tar.gz
        mkdir -p ${BINARY_DIR}/etcd
        tar zxvf etcd-${etcd_version}-linux-amd64.tar.gz -C ${BINARY_DIR}/etcd --strip-components=1
        rm -rf ${BINARY_DIR}/etcd/Documentation
        rm -f ${BINARY_DIR}/etcd/*.md
    fi
}

function download_kubernetes_rpm (){
    # yum --disablerepo="*" --enablerepo="kubernetes" list available
    yum install -y --downloadonly --downloaddir=${KUBERNETES_RPM_DIR} kubelet-${KUBERNETES_VERSION}-0 kubeadm-${KUBERNETES_VERSION}-0 kubectl-${KUBERNETES_VERSION}-0
}

function download_images (
    # master nodes
    docker save -o ${IMAGE_DIR}/master.tar.gz \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver:v${KUBERNETES_VERSION} \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v${KUBERNETES_VERSION} \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager:v${KUBERNETES_VERSION}
    # all nodes
    docker save -o ${IMAGE_DIR}/all.tar.gz \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:v${KUBERNETES_VERSION} \
        registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.5
    # worker nodes
    docker save -o ${IMAGE_DIR}/worker.tar.gz \
        coredns/coredns:${COREDNS_VERSION}
)

function download () {
    create_dir
    config_yum_repo
    download_kernel_rpm
    download_chrony_rpm
    download_dependence_rpm
    download_container_runtime_rpm
    download_containerd_binary
    download_etcd_binary
    download_kubernetes_rpm
    download_images
}

download | tee download.log
