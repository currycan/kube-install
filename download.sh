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

KUBERNETES_VERSION=`curl -sSf https://storage.googleapis.com/kubernetes-release/release/stable.txt | grep -v %`

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
        ebtables \
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

function download_kubernetes_rpm (){
    # yum --disablerepo="*" --enablerepo="kubernetes" list available
    yum install -y --downloadonly --downloaddir=${KUBERNETES_RPM_DIR} kubelet-${KUBERNETES_VERSION:1}-0 kubeadm-${KUBERNETES_VERSION:1}-0 kubectl-${KUBERNETES_VERSION:1}-0
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
        rm -rf ${BINARY_DIR}/containerd/etc
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

function download_docker_binary (){
    if [ ! -d ${BINARY_DIR}/docker ];then
        cd /tmp
        docker_version=`curl -sSf https://download.docker.com/linux/static/stable/x86_64/ | grep -e docker- | tail -n 1 | cut -d">" -f1 | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*"`
        curl -fSLO https://download.docker.com/linux/static/stable/x86_64/docker-${docker_version}.tgz
        mkdir -p ${BINARY_DIR}/docker
        tar zxvf docker-${docker_version}.tgz -C ${BINARY_DIR}
    fi
}

function download_etcd_binary (){
    if [ ! -d ${BINARY_DIR}/etcd ];then
        cd /tmp
        etcd_version=`curl -sSf https://github.com/etcd-io/etcd/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | head -n 1 | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*"`
        curl -fSLO https://github.com/etcd-io/etcd/releases/download/${etcd_version}/etcd-${etcd_version}-linux-amd64.tar.gz
        mkdir -p ${BINARY_DIR}/etcd
        tar zxvf etcd-${etcd_version}-linux-amd64.tar.gz -C ${BINARY_DIR}/etcd --strip-components=1
        rm -rf ${BINARY_DIR}/etcd/Documentation
        rm -f ${BINARY_DIR}/etcd/*.md
    fi
}

function download_kubernetes_binary (){
    if [ ! -d ${BINARY_DIR}/kubernetes ];then
        cd /tmp
        curl -fSLO "https://dl.k8s.io/${KUBERNETES_VERSION}/kubernetes-server-linux-amd64.tar.gz"
        mkdir -p ${BINARY_DIR}/{kube_tmp,kubernetes}
        tar zxvf kubernetes-server-linux-amd64.tar.gz -C ${BINARY_DIR}/kube_tmp --strip-components=3
        mv ${BINARY_DIR}/kube_tmp/kube* ${BINARY_DIR}/kubernetes
        rm -rf ${BINARY_DIR}/kube_tmp
        rm -f ${BINARY_DIR}/kubernetes/{*.docker_tag,*.tar,kube-aggregator,kubectl-convert}
    fi
}

function download_cfssl_binary (){
    if [ ! -d ${BINARY_DIR}/cfssl ];then
        mkdir -p ${BINARY_DIR}/cfssl
        cfssl_version=`curl -sSf https://github.com/cloudflare/cfssl/tags | grep "releases/tag/" | head -n 1 | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*"`
        # curl -fSLo ${BINARY_DIR}/cfssl/cfssl-bundle "https://github.com/cloudflare/cfssl/releases/download/${cfssl_version}/cfssl-bundle_${cfssl_version:1}_linux_amd64"
        curl -fSLo ${BINARY_DIR}/cfssl/cfssl-certinfo "https://github.com/cloudflare/cfssl/releases/download/${cfssl_version}/cfssl-certinfo_${cfssl_version:1}_linux_amd64"
        # curl -fSLo ${BINARY_DIR}/cfssl/cfssl-newkey "https://github.com/cloudflare/cfssl/releases/download/${cfssl_version}/cfssl-newkey_${cfssl_version:1}_linux_amd64"
        # curl -fSLo ${BINARY_DIR}/cfssl/cfssl-scan "https://github.com/cloudflare/cfssl/releases/download/${cfssl_version}/cfssl-scan_${cfssl_version:1}_linux_amd64"
        curl -fSLo ${BINARY_DIR}/cfssl/cfssl "https://github.com/cloudflare/cfssl/releases/download/${cfssl_version}/cfssl_${cfssl_version:1}_linux_amd64"
        curl -fSLo ${BINARY_DIR}/cfssl/cfssljson "https://github.com/cloudflare/cfssl/releases/download/${cfssl_version}/cfssljson_${cfssl_version:1}_linux_amd64"
        # curl -fSLo ${BINARY_DIR}/cfssl/mkbundle "https://github.com/cloudflare/cfssl/releases/download/${cfssl_version}/mkbundle_${cfssl_version:1}_linux_amd64"
        # curl -fSLo ${BINARY_DIR}/cfssl/multirootca_ "https://github.com/cloudflare/cfssl/releases/download/${cfssl_version}/multirootca_${cfssl_version:1}_linux_amd64"
        chmod 755 ${BINARY_DIR}/cfssl/*
    fi
}

function download_images (){
    # master nodes
    image_repo="registry.cn-hangzhou.aliyuncs.com/google_containers"
    master_images="kube-apiserver:${KUBERNETES_VERSION} kube-scheduler:${KUBERNETES_VERSION} kube-controller-manager:${KUBERNETES_VERSION}"
    for img in ${master_images};
    do
        docker pull ${image_repo}/${img}
    done
    docker save -o ${IMAGE_DIR}/master.tar.gz \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver:${KUBERNETES_VERSION} \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:${KUBERNETES_VERSION} \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager:${KUBERNETES_VERSION}
    # all nodes
    PAUSE_VERSION=`curl -sSf https://github.com/kubernetes/kubernetes/blob/master/build/pause/CHANGELOG.md | grep "</h1>" | head -n 2 | grep [0-9]\d*.[0-9]\d* -oP | tail -n 1`
    docker pull ${image_repo}/kube-proxy:${KUBERNETES_VERSION}
    docker pull ${image_repo}/pause:${PAUSE_VERSION}
    docker save -o ${IMAGE_DIR}/all.tar.gz \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:${KUBERNETES_VERSION} \
        registry.cn-hangzhou.aliyuncs.com/google_containers/pause:${PAUSE_VERSION}
    # worker nodes
    COREDNS_VERSION=`curl -sSf https://github.com/coredns/coredns/tags | grep "releases/tag/" | head -n 1 | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*"`
    docker pull coredns/coredns:${COREDNS_VERSION:1}
    docker save -o ${IMAGE_DIR}/worker.tar.gz \
        coredns/coredns:${COREDNS_VERSION:1}
}

function download () {
    create_dir
    config_yum_repo
    download_kernel_rpm
    download_chrony_rpm
    download_dependence_rpm
    download_container_runtime_rpm
    download_kubernetes_rpm
    download_containerd_binary
    download_docker_binary
    download_etcd_binary
    download_kubernetes_binary
    download_cfssl_binary
    download_images
}

download | tee download.log
