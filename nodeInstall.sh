#!/bin/bash

sudo swapoff -a
sleep 20
printf "disable swap"
sysctl net.bridge.bridge-nf-call-iptables=1
sleep 20
printf "setting iptables"
sudo apt-get update
sleep 20
printf "updating apt"
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
sleep 20
printf "installed common libs"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
sleep 20
printf "adding gpg key"
add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) \
stable"
sleep 20
printf "added repo"
sudo apt-get update && sudo apt-get install docker-ce -y
sleep 20
printf "installed docker"
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
sleep 20
echo "added cgroup config"
mkdir -p /etc/systemd/system/docker.service.d
sleep 20
printf "adding docker to services"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
sleep 20
printf "adding kube gpg key"
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sleep 20
printf "probably where this script is going to break"
apt-get update
sleep 20
printf "updating apt"
sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
printf "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sleep 20
printf "adding kube repo to apt"
sudo apt-get update
apt-get install -y kubelet kubeadm kubectl kubernetes-cni
sleep 20
printf "installing kube*"
apt-mark hold kubelet kubeadm kubectl kubernetes-cni
sleep 20
printf "holding kube versions with apt"
systemctl daemon-reload
systemctl restart docker
systemctl restart kubelet
printf "services have restarted, installation should be completed"
printf "time to run the kubeadm join command"