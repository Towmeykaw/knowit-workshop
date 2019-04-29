#!/bin/bash

numOfNamespaces=1

usage ()
{
    echo "usage: eksctl-setup -c numberOfNamespaces -h help"
}

while [ "$1" != "" ]; do
    case $1 in
        -n | --namespaceCount ) shift
                                numOfNamespaces=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done


eksctl create cluster --name=tesing --nodes=1 --region=eu-north-1

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml

kubectl create -n kube-system serviceaccount admin-user

kubectl create clusterrolebinding permissive-binding \
  --clusterrole=cluster-admin \
  --user=admin-user \
  --user=kubelet \
  --group=system:serviceaccounts

# This will get the admin password and copy it to the clipboard. Only works on Wsl for now 
# kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}') | grep token: | cut -d ':' -f 2 | awk '{$1=$1};1' | clip.exe  

helm init

helm repo update

helm install stable/metrics-server --name metrics-server

for ((i=1;i<=numOfNamespaces;++i))
do
kubectl create namespace "namespace-$i"

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: namespace-$i-user
  namespace: namespace-$i
--- 
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: "namespace-$i-user-full-access"
  namespace: "namespace-$i"
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources:
  - jobs
  - cronjobs
  verbs: ["*"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: namespace-$i-user-view
  namespace: namespace-$i
subjects:
- kind: ServiceAccount
  name: namespace-$i-user
  namespace: namespace-$i
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-$i-user-full-access
EOF
done

# In wsl this will launch firefox on the correct page
# firefox.exe  http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/ 

kubectl proxy


