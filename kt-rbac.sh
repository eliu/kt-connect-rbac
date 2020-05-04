#!/usr/bin/env bash
set -e

# --- common functions ---
info() { echo "$(tput setaf 76)[INFO]$(tput sgr0)" "$@"
}
fata() { echo "$(tput setaf 1)[FATA]$(tput sgr0)" "$@"; exit 1
}
command_exists() { command -v "$@" > /dev/null 2>&1
}

# --- Initialize config ---
init_config() {
  export KUBE_CLUSTER_NAME="${KUBE_CLUSTER_NAME:-kubernetes}"
  export KUBE_API_SERVER_PORT="${KUBE_API_SERVER_PORT:-8443}"
  export KUBE_API_SERVER="https://$(hostname -i | cut -d' ' -f1):${KUBE_API_SERVER_PORT}"
  export KUBE_CERT="${KUBE_CERT:-/etc/kubernetes/pki/ca.crt}"
  export KUBE_CERT_KEY="${KUBE_CERT_KEY:-/etc/kubernetes/pki/ca.key}"
  export KT_NAMESPACE="${NAMESPACE:-default}"
  export KT_AUTH_USER="${AUTH_USER:-kt-connect}"
  export KT_LOG_FILE="kt-rbac.log"
}

# --- check arguments and cli tools ---
prerequisite() {
  local machine=$(uname -s)
  [[ $machine == "Linux" ]] || fata "$machine not supported."

  command_exists kubectl || fata "'kubectl' was not installed on your server."

  init_config

  # 检查集群证书位置是否合法
  if [[ ! -f $KUBE_CERT ]] || [[ ! -f $KUBE_CERT_KEY ]]; then
    fata "Cluster cert not found."
    info "Use \$KUBE_CERT and \$KUBE_CERT_KEY to specify cluster cert path."
  fi
}

# --- Grant user full access to the specified namespace ONLY. ---
# $KT_AUTH_USER provides the role binding user name
# $KT_NAMESPACE provides the namespace you would like to apply
# https://kubernetes.io/docs/reference/access-authn-authz/rbac/
create_rbac() {
  info "Applying RBAC for user '$KT_AUTH_USER' at namespace '$KT_NAMESPACE' ..."
  cat kt-rbac.yaml.j2 \
  | sed "s/{{ namespace }}/$KT_NAMESPACE/g" \
  | sed "s/{{ user }}/$KT_AUTH_USER/g" \
  | kubectl apply -f -
}

# --- 为用户生成证书和秘钥 ---
# 当前目录下会生成 <user>.crt, <user>.csr 和 <user>.key
# https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/
create_user_cert() {
  if [ -d "users/$KT_AUTH_USER" ]; then
    info "Cert for user $KT_AUTH_USER already been generated before."
    return 0
  fi
  mkdir -p "users/$KT_AUTH_USER"
  info "Generate certificate for user $KT_AUTH_USER ..."
  openssl genrsa \
    -out users/$KT_AUTH_USER/$KT_AUTH_USER.key 2048 \
    >> $KT_LOG_FILE 2>&1
  openssl req -new \
    -key users/$KT_AUTH_USER/$KT_AUTH_USER.key \
    -out users/$KT_AUTH_USER/$KT_AUTH_USER.csr \
    -subj "/CN=$KT_AUTH_USER/O=kt" \
    >> $KT_LOG_FILE 2>&1
  openssl x509 -req \
    -in users/$KT_AUTH_USER/$KT_AUTH_USER.csr \
    -CA "$KUBE_CERT" \
    -CAkey "$KUBE_CERT_KEY" \
    -CAcreateserial \
    -out users/$KT_AUTH_USER/$KT_AUTH_USER.crt \
    -days 500 \
    >> $KT_LOG_FILE 2>&1
}

# --- 为 kt-connect 用户生成配置文件 ---
# https://blog.csdn.net/weixin_34409741/article/details/86279147
create_kubeconfig() {
  info "Generate kubeconfig for user $KT_AUTH_USER to access namespace $KT_NAMESPACE ..."
  export KUBECONFIG="certs/$KT_NAMESPACE/$KT_AUTH_USER.kubeconfig"
  mkdir -p certs/$KT_NAMESPACE
  touch $KUBECONFIG
  chmod 600 $KUBECONFIG

  # 设置集群参数
  kubectl config set-cluster $KUBE_CLUSTER_NAME \
    --embed-certs=true \
    --certificate-authority="$KUBE_CERT" \
    --server=$KUBE_API_SERVER \
    >> $KT_LOG_FILE

  # 设置客户端认证参数 指定用户名和key
  kubectl config set-credentials $KT_AUTH_USER \
    --embed-certs=true \
    --client-certificate=users/$KT_AUTH_USER/$KT_AUTH_USER.crt \
    --client-key=users/$KT_AUTH_USER/$KT_AUTH_USER.key \
    >> $KT_LOG_FILE

  # 设置上下文参数
  kubectl config set-context $KT_AUTH_USER@$KUBE_CLUSTER_NAME \
    --cluster=$KUBE_CLUSTER_NAME \
    --namespace=$KT_NAMESPACE \
    --user=$KT_AUTH_USER \
    >> $KT_LOG_FILE

  # 设置默认上下文
  kubectl config use-context $KT_AUTH_USER@$KUBE_CLUSTER_NAME >> $KT_LOG_FILE
  info "kubeconfig file has been saved at '$KUBECONFIG'"
}

{
  prerequisite
  create_rbac
  create_user_cert
  create_kubeconfig
}
