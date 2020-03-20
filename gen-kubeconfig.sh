#!/usr/bin/env bash
set -e

. config.env

# --- common functions ---
info() { echo "$(tput setaf 76)[INFO]$(tput sgr0)" "$@"
}
fatal() { echo "$(tput setaf 1)[FATA]$(tput sgr0)" "$@"; exit 1
}

# --- 为用户生成证书和秘钥 ---
# 当前目录下会生成 user.crt, user.csr 和 user.key
# https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/
gen_certificate() {
  info "Generate certificate for user $AUTH_USER ..."
  openssl genrsa \
    -out certs/$NAMESPACE/$AUTH_USER.key 2048 \
    > certs/$NAMESPACE/$AUTH_USER.log 2>&1
  openssl req -new \
    -key certs/$NAMESPACE/$AUTH_USER.key \
    -out certs/$NAMESPACE/$AUTH_USER.csr \
    -subj "/CN=$AUTH_USER/O=srm" \
    >> certs/$NAMESPACE/$AUTH_USER.log 2>&1
  openssl x509 -req \
    -in certs/$NAMESPACE/$AUTH_USER.csr \
    -CA "$CLUSTER_CERT_PATH" \
    -CAkey "$CLUSTER_CERT_KEY_PATH" \
    -CAcreateserial \
    -out certs/$NAMESPACE/$AUTH_USER.crt \
    -days 500 \
    >> certs/$NAMESPACE/$AUTH_USER.log 2>&1
}

# --- 为 kt-connect 用户生成配置文件 ---
# https://blog.csdn.net/weixin_34409741/article/details/86279147
gen_kubeconfig() {
  info "Generate kubeconfig for user $AUTH_USER to access namespace $NAMESPACE ..."
  export KUBECONFIG="certs/$NAMESPACE/$AUTH_USER.kubeconfig"
  touch $KUBECONFIG
  chmod 600 $KUBECONFIG

  # 设置集群参数
  kubectl config set-cluster kubernetes \
    --embed-certs=true \
    --certificate-authority="$CLUSTER_CERT_PATH" \
    --server=$SERVER \
    >> certs/$NAMESPACE/$AUTH_USER.log

  # 设置客户端认证参数 指定用户名和key
  kubectl config set-credentials $AUTH_USER \
    --embed-certs=true \
    --client-certificate=certs/$NAMESPACE/$AUTH_USER.crt \
    --client-key=certs/$NAMESPACE/$AUTH_USER.key \
    >> certs/$NAMESPACE/$AUTH_USER.log

  # 设置上下文参数
  kubectl config set-context $AUTH_USER-context \
    --cluster=kubernetes \
    --namespace=$NAMESPACE \
    --user=$AUTH_USER \
    >> certs/$NAMESPACE/$AUTH_USER.log

  # 设置默认上下文
  kubectl config use-context $AUTH_USER-context >> certs/$NAMESPACE/$AUTH_USER.log
  info "kubeconfig file has been saved at '$KUBECONFIG'"
}

{
  # 检查集群证书位置是否合法
  if [[ ! -f $CLUSTER_CERT_PATH ]] || [[ ! -f $CLUSTER_CERT_KEY_PATH ]]; then
    fatal "Cluster cert not found. Please check 'config.env' file and set correct value."
  fi
  mkdir -p certs/$NAMESPACE
  gen_certificate
  gen_kubeconfig
}
