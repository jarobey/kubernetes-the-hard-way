#!/bin/bash

# CONFIG
NAMES_O="RobeyDeSpain Instabase"
NAMES_OU="RobeyDeSpain Instabase"
KUBERNETES_PUBLIC_ADDRESS=10.40.184.228
WORKER_IP[0]="10.40.184.10"
WORKER_IP[1]="10.40.184.242"
WORKER_IP[2]="10.40.184.164"
OUTPUT="/etc/kubernetes/kpi/"

# Certificate Authority
{

cat > ${OUTPUT}ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ${OUTPUT}ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "$NAMES_O",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ${OUTPUT}ca-csr.json | cfssljson -bare ca
mv ca*.* ${OUTPUT}
}

# Client and Server Certificates

# The Admin Client Certificate
# In this section you will generate client and server certificates for each Kubernetes component 
# and a client certificate for the Kubernetes admin user.
{

cat > ${OUTPUT}admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "$NAMES_OU",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${OUTPUT}ca.pem \
  -ca-key=${OUTPUT}ca-key.pem \
  -config=${OUTPUT}ca-config.json \
  -profile=kubernetes \
  ${OUTPUT}admin-csr.json | cfssljson -bare admin
mv admin*.* ${OUTPUT}
}

# The Kubelet Client Certificates
# Kubernetes uses a special-purpose authorization mode called Node Authorizer, that specifically 
# authorizes API requests made by Kubelets. In order to be authorized by the Node Authorizer, 
# Kubelets must use a credential that identifies them as being in the system:nodes group, with a 
# username of system:node:<nodeName>. In this section you will create a certificate for each 
# Kubernetes worker node that meets the Node Authorizer requirements.
i=0
for instance in kworker1 kworker2 kworker3; do
cat > ${OUTPUT}${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "$NAMES_OU",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${OUTPUT}ca.pem \
  -ca-key=${OUTPUT}ca-key.pem \
  -config=${OUTPUT}ca-config.json \
  -hostname=${instance},${WORKER[$i]} \
  -profile=kubernetes \
  ${OUTPUT}${instance}-csr.json | cfssljson -bare ${instance}
i=$i+1
mv ${instance}*.* ${OUTPUT}
done

# The Controller Manager Client Certificate
{

cat > ${OUTPUT}kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "$NAMES_OU",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${OUTPUT}ca.pem \
  -ca-key=${OUTPUT}ca-key.pem \
  -config=${OUTPUT}ca-config.json \
  -profile=kubernetes \
  ${OUTPUT}kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
mv kube-controller-manager*.* ${OUTPUT}
}

# The Kube Proxy Client Certificate
{

cat > ${OUTPUT}kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "$NAMES_OU",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${OUTPUT}ca.pem \
  -ca-key=${OUTPUT}ca-key.pem \
  -config=${OUTPUT}ca-config.json \
  -profile=kubernetes \
  ${OUTPUT}kube-proxy-csr.json | cfssljson -bare kube-proxy
mv kube-proxy*.* ${OUTPUT}
}

# The Scheduler Client Certificate
{

cat > ${OUTPUT}kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "$NAMES_OU",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${OUTPUT}ca.pem \
  -ca-key=${OUTPUT}ca-key.pem \
  -config=${OUTPUT}ca-config.json \
  -profile=kubernetes \
  ${OUTPUT}kube-scheduler-csr.json | cfssljson -bare kube-scheduler
mv kube-scheduler*.* ${OUTPUT}
}

# The Kubernetes API Server Certificate
# The kubernetes-the-hard-way static IP address will be included in the list of subject alternative 
# names for the Kubernetes API Server certificate. This will ensure the certificate can be validated by remote clients.
{

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > ${OUTPUT}kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "$NAMES_O",
      "OU": "$NAMES_OU",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${OUTPUT}ca.pem \
  -ca-key=${OUTPUT}ca-key.pem \
  -config=${OUTPUT}ca-config.json \
  -hostname=2001:470:b:320::aaa,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  ${OUTPUT}kubernetes-csr.json | cfssljson -bare kubernetes
mv kubernetes*.* ${OUTPUT}
}

# Service account key pair
# The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as described in the managing service accounts documentation. 
{

cat > ${OUTPUT}service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "$NAMES_O",
      "OU": "$NAMES_OU",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${OUTPUT}ca.pem \
  -ca-key=${OUTPUT}ca-key.pem \
  -config=${OUTPUT}ca-config.json \
  -profile=kubernetes \
  ${OUTPUT}service-account-csr.json | cfssljson -bare service-account
mv service-account*.* ${OUTPUT}
}

# Copy the appropriate certificates and private keys to each worker instance:
#for instance in worker-0 worker-1 worker-2; do
#  gcloud compute scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
#done

# Copy the appropriate certificates and private keys to each controller instance:
#for instance in controller-0 controller-1 controller-2; do
#  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
#    service-account-key.pem service-account.pem ${instance}:~/
#done

