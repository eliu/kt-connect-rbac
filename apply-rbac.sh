#!/usr/bin/env bash
set -e

USAGE="Usage: $0 <user> [-n namespace]"

# --- common functions ---
info() { echo "$(tput setaf 76)[INFO]$(tput sgr0)" "$@"
}
fatal() { echo "$(tput setaf 1)[FATA]$(tput sgr0)" "$@"; exit 1
}
command_exists() { command -v "$@" > /dev/null 2>&1
}

# --- check arguments and cli tools ---
prerequisite() {
  [[ $# -ge 1 ]] || fatal "Not enough arguments. $USAGE"

  if [[ $2 = "-n" ]] && [[ -z "$3" ]]; then
    fatal "Namespace must be provided. $USAGE"
  fi

  command_exists kubectl || fatal "'kubectl' was not installed on your server."
}

# --- Grant user full access to the specified namespace ONLY. ---
# $1 provides the role binding user name
# $2 provides the namespace you would like to apply
# https://kubernetes.io/docs/reference/access-authn-authz/rbac/
apply_rbac() {
  info "Applying RBAC for user '$1' at namespace '$2' ..."
  cat ns-rbac.yaml.j2 \
  | sed "s/{{ namespace }}/$2/g" \
  | sed "s/{{ user }}/$1/g" \
  | kubectl apply -f -
}

{
  prerequisite $@
  apply_rbac "$1" "${3:-default}"
}
