cd ./terraform
terraform init
terraform plan
terraform apply -auto-approve
cd ..

openssl \
     req \
    -x509 \
    -nodes \
    -newkey rsa:4096 \
    -keyout helloworld.key \
    -out helloworld.crt \
    -days 3650 \
    -subj "/C=XX/ST=XX/L=XX/O=XX/OU=IT/CN=helloworld.net/emailAddress=nikitinay@helloworld.net"

crt=$(cat helloworld.crt | base64 -w0)
key=$(cat helloworld.key | base64 -w0)

cat <<EOF >k8sdeploy/tls-cert.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-cert
data:
  tls.crt: $crt
  tls.key: $key
type: kubernetes.io/tls
EOF

tfState=./terraform/terraform.tfstate

nodeARN=$(cat "$tfState" | jq -r '. | .resources[]? | select(.type=="aws_iam_role") | select(.name=="node") | .instances[]? | .attributes.arn')

cat <<EOF >k8sdeploy/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${nodeARN}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

export KUBECONFIG=./terraform/cluster.kube-config
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/aws/deploy.yaml
# to avoid error with endpoints
sleep 60
kubectl apply -f k8sdeploy/
