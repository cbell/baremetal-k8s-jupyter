# Setting up Jupyterhub on baremetal K8s cluster
This will guide through the insallation of setting a cluster of physical hosts to run Jupyter notebooks.
### Assumptions: 
- No load balancer is in place on the network 
- Single node is being used for network ingress
- Configuration of authentication, shared storage and external integrations are already setup 
- Physical hosts have network connectivity between them 

# Setting up the master:
## Setting up master: 
1. Update system and install some basic packages:

        sudo apt-get update 

        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

2. Add Docker gpg key and install on system:

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

        add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable" 

        sudo apt-get update && sudo apt-get install docker-ce

3. Set Docker daemon to run using systemd cgroup:

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

        mkdir -p /etc/systemd/system/docker.service.d

4. Add Kubernetes gpg key, install on system: 

        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

        cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
        deb https://apt.kubernetes.io/ kubernetes-xenial main
        EOF

        apt-get update

        sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        apt-get install -y kubelet kubeadm kubectl kubernetes-cni

        apt-mark hold kubelet kubeadm kubectl kubernetes-cni

5. Disable swap and change iptables:

        sudo swapoff -a 
        sysctl net.bridge.bridge-nf-call-iptables=1


6. Restart services to reapply configurations: 

        systemctl daemon-reload
        systemctl restart docker 
        systemctl restart kubelet 

## Run only once on master node: 

7. Initialize kubernetes:

        kubeadm init --pod-network-cidr=10.244.0.0/16

        sysctl net.bridge.bridge-nf-call-iptables=1

8. Install flannel networking to allow communcation between nodes:

        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

        kubectl taint nodes --all node-role.kubernetes.io/master- 

9. Install Helm, create service account for Helm:

        curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash 
        kubectl --namespace kube-system create serviceaccount tiller 
        kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller

10. Initialize Helm into cluster:

        helm init --service-account tiller --wait 

        kubectl patch deployment tiller-deploy --namespace=kube-system --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'

11. Instll Helm nfs-server-provisioner 

        helm repo update 
        helm install stable/nfs-server-provisioner --namespace nfsprovisioner --set=storageClass.defaultClass=true 

12. Install MetalLB

        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
        kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

13. Configure MetalLB - update the metal_config.yaml document with IP addresses 

        kubectl apply -f metal_config.yaml

        kubectl logs -l component=speaker -n metallb-system

14. Install nginx-ingress to cluster: 

        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm install nginx-ingress ingress-nginx/ingress-nginx


15. Install Jupyterhub using helm: 

        helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
        helm repo update 

        helm upgrade --install jupyterhub --namespace jupyterhub jupyterhub/jupyterhub --values config.yaml --debug 

> This assumes you already have a Helm chart to install. More can be found regarding these charts at the Zero to K8s documentation: https://zero-to-jupyterhub.readthedocs.io/en/latest/setup-jupyterhub/setup-jupyterhub.html

# Setting up the nodes: 
## Run on nodes: 
> All of the following commands are in a functional (but not pretty) script inside of the repository: nodeInstall.sh
> It will make the neccesary changes to configuration and install docker and kubernetes tools on the nodes. Afterward you will need to join to the cluster with the command given to you previously on the master. 
1. Update system and install some basic packages:

        sudo apt-get update 

        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

2. Add Docker gpg key and install on system:

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

        add-apt-repository \
            "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable" 

        sudo apt-get update && sudo apt-get install docker-ce

3. Set Docker daemon to run using systemd cgroup:

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

        mkdir -p /etc/systemd/system/docker.service.d

4. Add Kubernetes gpg key, install on system: 

        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

        cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
        deb https://apt.kubernetes.io/ kubernetes-xenial main
        EOF

        apt-get update

        sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        apt-get install -y kubelet kubeadm kubectl kubernetes-cni

        apt-mark hold kubelet kubeadm kubectl kubernetes-cni
5. Disable swap and change iptables:

        sudo swapoff -a 
        sysctl net.bridge.bridge-nf-call-iptables=1

6. Restart services to reapply configurations: 

        systemctl daemon-reload
        systemctl restart docker 
        systemctl restart kubelet 

7. Run the kubeadm join command that was exported earlier

