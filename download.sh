#! /bin/env bash

# docker run --name download -it \
#     -v $PWD/k8s_cache/:/k8s_cache \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     -v /Volumes/others/Github/ansible-kubeadm/download.sh:/download.sh \
#     centos:7 bash

# docker run --name download -it \
#     -v $PWD/k8s_cache/:/k8s_cache \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     -v /etc/ansible/download.sh:/download.sh \
#     centos:7 bash
# docker start -i download

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
    echo ">>>>>>: 开始下载内核 rpm 包"
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
    echo ">>>>>>: 开始下载 docker rpm 包"
    yum install -y --downloadonly --downloaddir=${CHRONY_RPM_DIR} chrony
}

function download_dependence_rpm (){
    echo ">>>>>>: 开始下载环境依赖 rpm 包"
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
    echo ">>>>>>: 开始下载 containerd rpm 包"
    yum install -y yum-utils
    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum install -y --downloadonly --downloaddir=${CONTIANERD_RPM_DIR} containerd.io
    yum install -y --downloadonly --downloaddir=${DOCKER_RPM_DIR} docker-ce docker-ce-cli containerd.io
}

function download_kubernetes_rpm (){
    echo ">>>>>>: 开始下载 kubernetes rpm 包"
    # yum --disablerepo="*" --enablerepo="kubernetes" list available
    yum install -y --downloadonly --downloaddir=${KUBERNETES_RPM_DIR} kubelet-${KUBE_VERSION}-0 kubeadm-${KUBE_VERSION}-0 kubectl-${KUBE_VERSION}-0
}

function download_containerd_binary (){
    echo ">>>>>>: 开始下载 containerd 二进制包"
    # containerd
    if [ ! -d ${BINARY_DIR}/containerd ];then
        cd /tmp
        curl -fSLO https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/cri-containerd-cni-${CONTAINERD_VERSION}-linux-amd64.tar.gz
        mkdir -p ${BINARY_DIR}/containerd
        tar zxf cri-containerd-cni-${CONTAINERD_VERSION}-linux-amd64.tar.gz -C ${BINARY_DIR}/containerd
        rm -rf ${BINARY_DIR}/containerd/opt/containerd
        rm -rf ${BINARY_DIR}/containerd/etc
    fi
    # crictl
    if [ ! -f ${BINARY_DIR}/crictl/crictl ];then
        cd /tmp
        curl -fSLO https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz
        mkdir -p ${BINARY_DIR}/crictl
        tar zxf crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz -C ${BINARY_DIR}/crictl
    fi
}

function download_docker_binary (){
    echo ">>>>>>: 开始下载 docker 二进制包"
    if [ ! -d ${BINARY_DIR}/docker ];then
        cd /tmp
        curl -fSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz
        mkdir -p ${BINARY_DIR}/docker
        tar zxf docker-${DOCKER_VERSION}.tgz -C ${BINARY_DIR}
    fi
}

function download_etcd_binary (){
    echo ">>>>>>: 开始下载 etcd 二进制包"
    if [ ! -d ${BINARY_DIR}/etcd ];then
        cd /tmp
        curl -fSLO https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
        mkdir -p ${BINARY_DIR}/etcd
        tar zxf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -C ${BINARY_DIR}/etcd --strip-components=1
        rm -rf ${BINARY_DIR}/etcd/Documentation
        rm -f ${BINARY_DIR}/etcd/*.md
    fi
}

function download_kubernetes_binary (){
    echo ">>>>>>: 开始下载 kubernetes 二进制包"
    if [ ! -d ${BINARY_DIR}/kubernetes ];then
        cd /tmp
        curl -fSLO "https://dl.k8s.io/v${KUBE_VERSION}/kubernetes-server-linux-amd64.tar.gz"
        mkdir -p ${BINARY_DIR}/{kube_tmp,kubernetes}
        tar zxf kubernetes-server-linux-amd64.tar.gz -C ${BINARY_DIR}/kube_tmp --strip-components=3
        mv ${BINARY_DIR}/kube_tmp/kube* ${BINARY_DIR}/kubernetes
        rm -rf ${BINARY_DIR}/kube_tmp
        rm -f ${BINARY_DIR}/kubernetes/{*.docker_tag,*.tar,kube-aggregator,kubectl-convert}
    fi
}

function download_helm_binary (){
    echo ">>>>>>: 开始下载 helm 二进制包"
    if [ ! -d ${BINARY_DIR}/helm ];then
        cd /tmp
        curl -fSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz"
        mkdir -p ${BINARY_DIR}/helm
        tar zxf helm-v${HELM_VERSION}-linux-amd64.tar.gz -C ${BINARY_DIR}/helm --strip-components=1
        rm -f ${BINARY_DIR}/helm/LICENSE
        rm -f ${BINARY_DIR}/helm/README.md
    fi
}

function download_cfssl_binary (){
    echo ">>>>>>: 开始下载 cfssl 二进制包"
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
    echo ">>>>>>: 开始下载依赖基础镜像"
    cp ${BINARY_DIR}/docker/docker /usr/local/bin/
    chmod 755 /usr/local/bin/docker
    # master nodes
    image_repo="registry.cn-hangzhou.aliyuncs.com/google_containers"
    master_images="kube-apiserver:v${KUBE_VERSION} kube-scheduler:v${KUBE_VERSION} kube-controller-manager:v${KUBE_VERSION}"
    for img in ${master_images};
    do
        docker pull ${image_repo}/${img}
    done
    docker save -o ${IMAGE_DIR}/master.tar.gz \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver:v${KUBE_VERSION} \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v${KUBE_VERSION} \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager:v${KUBE_VERSION}
    # all nodes
    docker pull ${image_repo}/kube-proxy:v${KUBE_VERSION}
    docker pull ${image_repo}/pause:${PAUSE_VERSION}
    docker save -o ${IMAGE_DIR}/all.tar.gz \
        registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:v${KUBE_VERSION} \
        registry.cn-hangzhou.aliyuncs.com/google_containers/pause:${PAUSE_VERSION}
    # worker nodes
    docker pull coredns/coredns:${COREDNS_VERSION}
    docker save -o ${IMAGE_DIR}/worker.tar.gz \
        coredns/coredns:${COREDNS_VERSION}
}

function version(){
    if [ -f ${BASE_DIR}/version.yml ];then
        components="kernel_offlie_version etcd_version kube_version containerd_version docker_version helm_version pause_version coredns_version"
        for cm in ${components};
        do
            export ${cm^^}=`grep $cm ${BASE_DIR}/version.yml | cut -d' ' -f2`
        done
    else
        # kernel
        KERNEL_OFFLIE_VERSION=`yum --disablerepo="*" --enablerepo=kernel-longterm-4.19 list kernel-longterm --showduplicates | sort -r | grep kernel-longterm | head -1 | awk -F' ' '{print $2}' | awk -F'.el7' '{print $1}'`
        # etcd
        ETCD_VERSION=`curl -sSf https://github.com/etcd-io/etcd/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | head -n 1 | grep -oP "[0-9]\d*\.[0-9]\d*\.[0-9]\d*"`
        # kubernetes
        KUBE_VERSION=`curl -sSf https://storage.googleapis.com/kubernetes-release/release/stable.txt | grep -v % | grep -oP "[0-9]\d*\.[0-9]\d*\.[0-9]\d*"`
        # containerd
        CONTAINERD_VERSION=`curl -sSf https://github.com/containerd/containerd/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -oP "[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1`
        # crictl
        CRICTL_VERSION=`curl -sSf https://github.com/kubernetes-sigs/cri-tools/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -oP "[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1`
        # docker
        DOCKER_VERSION=`curl -sSf https://download.docker.com/linux/static/stable/x86_64/ | grep -e docker- | tail -n 1 | cut -d">" -f1 | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*"`
        # helm
        HELM_VERSION=`curl -sSf https://github.com/helm/helm/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -oP "[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1`
        # infrastructure pause image
        PAUSE_VERSION=`curl -sSf https://github.com/kubernetes/kubernetes/blob/master/build/pause/CHANGELOG.md | grep "</h1>" | head -n 2 | grep [0-9]\d*.[0-9]\d* -oP | tail -n 1`
        # coreDns
        COREDNS_VERSION=`curl -sSf https://github.com/coredns/coredns/tags | grep "releases/tag/" | head -n 1 | grep -oP "[0-9]\d*\.[0-9]\d*\.[0-9]\d*"`
    fi
    echo 内核版本: $KERNEL_OFFLIE_VERSION
    echo etcd 版本: $ETCD_VERSION
    echo kubernetes 版本: $KUBE_VERSION
    echo containerd 版本: $CONTAINERD_VERSION
    echo docker 版本: $DOCKER_VERSION
    echo helm 版本: $HELM_VERSION
    echo pause_version 版本: $PAUSE_VERSION
    echo coreDns 版本: $COREDNS_VERSION
}

function set_version(){
    echo kernel_offlie_version: ${KERNEL_OFFLIE_VERSION} > ${BASE_DIR}/version.yml
    echo etcd_version: ${ETCD_VERSION} >> ${BASE_DIR}/version.yml
    echo kube_version: ${KUBE_VERSION} >> ${BASE_DIR}/version.yml
    echo containerd_version: ${CONTAINERD_VERSION} >> ${BASE_DIR}/version.yml
    echo docker_version: ${DOCKER_VERSION} >> ${BASE_DIR}/version.yml
    echo helm_version: ${HELM_VERSION} >> ${BASE_DIR}/version.yml
    echo pause_version: ${PAUSE_VERSION} >> ${BASE_DIR}/version.yml
    echo coredns_version: ${COREDNS_VERSION} >> ${BASE_DIR}/version.yml
}

function download () {
    create_dir
    config_yum_repo
    version
    download_kernel_rpm
    download_chrony_rpm
    download_dependence_rpm
    download_container_runtime_rpm
    download_kubernetes_rpm
    download_containerd_binary
    download_docker_binary
    download_helm_binary
    download_etcd_binary
    download_kubernetes_binary
    download_cfssl_binary
    download_images
    set_version
}

download | tee download.log
