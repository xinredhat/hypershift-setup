#!/usr/bin/env bash

#quit if exit status of any cmd is a non-zero value
set -euo pipefail

SCRIPT_DIR="$(
  cd "$(dirname "$0")" >/dev/null
  pwd
)"

ARGOCD_DIR="$SCRIPT_DIR/argocd"

install_openshift_gitops() {
  APP="openshift-gitops"

  local ns="$APP"

  #############################################################################
  # Install the gitops operator
  #############################################################################
  echo -n "- OpenShift-GitOps: "
  kubectl apply -k "$SCRIPT_DIR/openshift-operators/$APP" >/dev/null
  echo "OK"

  #############################################################################
  # Wait for the URL to be available
  #############################################################################
  echo -n "- Argo CD dashboard: "
  test_cmd="kubectl get route/openshift-gitops-server --ignore-not-found -n $ns -o jsonpath={.spec.host}"
  ARGOCD_HOSTNAME="$(${test_cmd})"
  until curl --fail --insecure --output /dev/null --silent "https://$ARGOCD_HOSTNAME"; do
    echo -n "."
    sleep 2
    ARGOCD_HOSTNAME="$(${test_cmd})"
  done
  echo "OK"
  echo "- Argo CD URL: https://$ARGOCD_HOSTNAME"

  #############################################################################
  # Post install
  #############################################################################
  # Log into Argo CD
  echo -n "- Argo CD Login: "
  local argocd_password
  argocd_password="$(kubectl get secret openshift-gitops-cluster -n $ns -o jsonpath="{.data.admin\.password}" | base64 --decode)"
  argocd login "$ARGOCD_HOSTNAME" --grpc-web --insecure --username admin --password "$argocd_password" >/dev/null
  echo "OK"

  # Register the host cluster as pipeline-cluster
  local cluster_name="host"
  if ! KUBECONFIG="$KUBECONFIG_MERGED" argocd cluster get "$cluster_name" >/dev/null 2>&1; then
    echo "- Register host cluster to ArgoCD as '$cluster_name': "
    argocd cluster add "$(yq e ".current-context" <"$KUBECONFIG")" --name="$cluster_name" --upsert --yes >/dev/null
    echo "  OK"
	else
    echo "- Register host cluster to ArgoCD as '$cluster_name': OK"
	fi
}

install_multicluster-engine() {
  kubectl apply -k $ARGOCD_DIR/argo-apps
}

install_hypershift() {

}

create_s3_bucket() {

}

setup_hypershift() {
  k apply -k hypershift-setup/base
  create_s3_bucket
  install_multicluster-engine
}

apply_tasks() {

}

main() {
  install_openshift_gitops
  create_s3_bucket
  install_hypershift
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi