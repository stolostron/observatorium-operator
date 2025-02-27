#!/bin/bash

set -e
set -o pipefail
set -x

ARTIFACT_DIR="${ARTIFACT_DIR:-/tmp/artifacts}"
KUBECTL="${KUBECTL:-./kubectl}"
KIND="${KIND:-./kind}"
OS_TYPE=$(echo `uname -s` | tr '[:upper:]' '[:lower:]')

SED_CMD="${SED_CMD:-sed}"

# OPERATOR_IMAGE_NAME can be set in the env to override calculated value
export OPERATOR_IMAGE_NAME="${OPERATOR_IMAGE_NAME:-quay.io/observatorium/observatorium-operator}"

test_kind_prow() {

    OPERATOR_IMAGE_NAME=$1

    KEY="$SHARED_DIR/private.pem"
    chmod 400 "$KEY"
    
    IP="$(cat "$SHARED_DIR/public_ip")"
    HOST="ec2-user@$IP"
    OPT=(-q -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -i "$KEY")
    # we tar the repo, transfer, then untar as newer version of SCP complaints
    # when copying folders with symlinks which we have in the vendor dir
    tar -czf /tmp/observatorium-operator.tar.gz ../observatorium-operator
    scp "${OPT[@]}" /tmp/observatorium-operator.tar.gz "$HOST:/tmp/"
    ssh "${OPT[@]}" "$HOST" "tar -xf /tmp/observatorium-operator.tar.gz -C /tmp/ && \
        cd /tmp/observatorium-operator && \
        export OPERATOR_IMAGE_NAME=${OPERATOR_IMAGE_NAME} && \
        . ./tests/e2e.sh kind && \
        . ./tests/e2e.sh deploy-operator && \
        . ./tests/e2e.sh test --tls && \
        . ./tests/e2e.sh delete-cr" 2>&1 | tee $ARTIFACT_DIR/test.log
}

kind() {
    curl -LO https://storage.googleapis.com/kubernetes-release/release/"$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"/bin/$OS_TYPE/amd64/kubectl
    curl -Lo kind https://github.com/kubernetes-sigs/kind/releases/download/v0.8.1/kind-$OS_TYPE-amd64
    chmod +x kind kubectl
    ./kind create cluster
}

dex() {
    $KUBECTL create ns dex || true
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-dex.yaml
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests/dex-secret.yaml
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests/dex-pvc.yaml
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests/dex-deployment.yaml
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests/dex-service.yaml
    # service CA for the first tenant, "test"
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/test-ca-tls.yaml

    # Observatorium needs the Dex API to be ready for authentication to work and thus for the tests to pass.
    $KUBECTL wait --for=condition=available --timeout=10m -n dex deploy/dex || (must_gather "$ARTIFACT_DIR" && exit 1)
}

deploy() {
    $KUBECTL apply -f https://raw.githubusercontent.com/coreos/kube-prometheus/release-0.9/manifests/setup/prometheus-operator-0servicemonitorCustomResourceDefinition.yaml
    $KUBECTL apply -f https://raw.githubusercontent.com/coreos/kube-prometheus/release-0.9/manifests/setup/prometheus-operator-0prometheusruleCustomResourceDefinition.yaml
    $KUBECTL create ns observatorium-minio || true
    $KUBECTL create ns observatorium || true
    dex
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests
}

wait_for_cr() {
    observatorium_cr_status=""
    target_status="Finished"
    timeout=$true
    interval=0
    intervals=600
    while [ $interval -ne $intervals ]; do
      echo "Waiting for" $1 "currentStatus="$observatorium_cr_status
      observatorium_cr_status=$($KUBECTL -n observatorium get observatoria.core.observatorium.io $1 -o=jsonpath='{.status.conditions[*].currentStatus}')
      if [ "$observatorium_cr_status" = "$target_status" ]; then
        echo $1 CR status is now: $observatorium_cr_status
	    timeout=$false
	    break
	  fi
	  sleep 5
	  interval=$((interval+5))
    done

    if [ $timeout ]; then
      echo "Timeout waiting for" $1 "CR status to be " $target_status
      exit 1
    fi
}

deploy_operator() {
    if [ "$OPERATOR_IMAGE_NAME" = "quay.io/observatorium/observatorium-operator:latest" ]; then    
        docker build -t quay.io/observatorium/observatorium-operator:latest .
        ./kind load docker-image quay.io/observatorium/observatorium-operator:latest
    else
        docker pull $OPERATOR_IMAGE_NAME
        IMAGE_ID=${OPERATOR_IMAGE_NAME%%@*}
        IMAGE_ID=${IMAGE_ID%%:*}
        docker tag $OPERATOR_IMAGE_NAME $IMAGE_ID:test
        ./kind load docker-image $IMAGE_ID:test
        OPERATOR_IMAGE_NAME=$IMAGE_ID:test
    fi
    $KUBECTL apply -f https://raw.githubusercontent.com/coreos/kube-prometheus/release-0.9/manifests/setup/prometheus-operator-0servicemonitorCustomResourceDefinition.yaml
    $KUBECTL apply -f https://raw.githubusercontent.com/coreos/kube-prometheus/release-0.9/manifests/setup/prometheus-operator-0prometheusruleCustomResourceDefinition.yaml
    $KUBECTL create ns observatorium-minio || true
    $KUBECTL create ns observatorium || true
    dex
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests/minio-secret-thanos.yaml
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests/minio-secret-loki.yaml
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests/minio-pvc.yaml
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests/minio-deployment.yaml
    $KUBECTL apply -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/examples/dev/manifests/minio-service.yaml
    $KUBECTL apply -n observatorium -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-configmap.yaml
    $KUBECTL apply -n observatorium -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-secret.yaml
    $KUBECTL apply -f manifests/crds --server-side=true
    $SED_CMD -i "s,quay.io/observatorium/observatorium-operator:latest,$OPERATOR_IMAGE_NAME," manifests/operator.yaml
    cat manifests/operator.yaml
    $KUBECTL apply -n default -f manifests/
    $KUBECTL apply -n observatorium -f example/manifests
    wait_for_cr observatorium-xyz
}

delete_cr() {
    $KUBECTL delete -n observatorium -f example/manifests
    target_count="0"
    timeout=$true
    interval=0
    intervals=600
    while [ $interval -ne $intervals ]; do
      echo "Waiting for cleaning"
      count=$($KUBECTL -n observatorium get all | wc -l)
      if [ "$count" = "$target_count" ]; then
        echo NS count is now: $count
	    timeout=$false
	    break
	  fi
	  sleep 5
	  interval=$((interval+5))
    done

    if [ $timeout ]; then
      echo "Timeout waiting for namespace to be empty"
      exit 1
    fi
}

run_test() {
    local suffix
    while [ $# -gt 0 ]; do
        case $1 in
            --tls)
                suffix=-tls
                ;;
        esac
        shift
    done

    $KUBECTL wait --for=condition=available --timeout=10m -n observatorium-minio deploy/minio || (must_gather "$ARTIFACT_DIR" && exit 1)
    $KUBECTL wait --for=condition=available --timeout=10m -n observatorium deploy/observatorium-xyz-thanos-query-frontend || (must_gather "$ARTIFACT_DIR" && exit 1)
    # $KUBECTL wait --for=condition=available --timeout=10m -n observatorium deploy/observatorium-xyz-loki-query-frontend || (must_gather "$ARTIFACT_DIR" && exit 1)
    $KUBECTL apply -n default -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-xyz-tls-configmap.yaml
    $KUBECTL apply -n default -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-up-metrics"$suffix".yaml

    sleep 5

    # This should wait for ~2min for the job to finish.
    $KUBECTL wait --for=condition=complete --timeout=5m -n default job/observatorium-up-metrics"$suffix" || (must_gather "$ARTIFACT_DIR" && exit 1)
    $KUBECTL apply -n default -f jsonnet/vendor/github.com/observatorium/observatorium/configuration/tests/manifests/observatorium-up-logs"$suffix".yaml

    sleep 5

    # This should wait for ~2min for the job to finish.
    # disable loki log checking
    # $KUBECTL wait --for=condition=complete --timeout=5m -n default job/observatorium-up-logs"$suffix" || (must_gather "$ARTIFACT_DIR" && exit 1)
}

must_gather() {
    local artifact_dir="$1"

    for namespace in default dex observatorium observatorium-minio; do
        mkdir -p "$artifact_dir/$namespace"

        for name in $($KUBECTL get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}') ; do
            $KUBECTL -n "$namespace" describe pod "$name" > "$artifact_dir/$namespace/$name.describe"
            echo "--- $artifact_dir/$namespace/$name.describe ---"
            cat "$artifact_dir/$namespace/$name.describe"

            $KUBECTL -n "$namespace" get pod "$name" -o yaml > "$artifact_dir/$namespace/$name.yaml"
            echo "--- $artifact_dir/$namespace/$name.yaml ---"
            cat "$artifact_dir/$namespace/$name.yaml"

            for initContainer in $($KUBECTL -n "$namespace" get po "$name" -o jsonpath='{.spec.initContainers[*].name}') ; do
                $KUBECTL -n "$namespace" logs "$name" -c "$initContainer" > "$artifact_dir/$namespace/$name-$initContainer.logs"
                echo "--- $artifact_dir/$namespace/$name-$initContainer.logs ---"
                cat "$artifact_dir/$namespace/$name-$initContainer.logs"
            done

            for container in $($KUBECTL -n "$namespace" get po "$name" -o jsonpath='{.spec.containers[*].name}') ; do
                $KUBECTL -n "$namespace" logs "$name" -c "$container" > "$artifact_dir/$namespace/$name-$container.logs"
                echo "--- $artifact_dir/$namespace/$name-$container.logs ---"
                cat "$artifact_dir/$namespace/$name-$container.logs"
            done
        done
    done

    $KUBECTL describe nodes > "$artifact_dir/nodes"
    echo "--- $artifact_dir/nodes ---"
    cat "$artifact_dir/nodes"
    $KUBECTL get pods --all-namespaces > "$artifact_dir/pods"
    echo "--- $artifact_dir/pods ---"
    cat "$artifact_dir/pods"
    $KUBECTL get deploy --all-namespaces > "$artifact_dir/deployments"
    echo "--- $artifact_dir/deployments ---"
    cat "$artifact_dir/deployments"
    $KUBECTL get statefulset --all-namespaces > "$artifact_dir/statefulsets"
    echo "--- $artifact_dir/statefulsets ---"
    cat "$artifact_dir/statefulsets"
    $KUBECTL get services --all-namespaces > "$artifact_dir/services"
    echo "--- $artifact_dir/services ---"
    cat "$artifact_dir/services"
    $KUBECTL get endpoints --all-namespaces > "$artifact_dir/endpoints"
    echo "--- $artifact_dir/endpoints ---"
    cat "$artifact_dir/endpoints"
}

case $1 in
test-kind-prow)
    test_kind_prow "${OPERATOR_IMAGE_NAME}"
    ;;

kind)
    kind
    ;;

deploy)
    deploy
    ;;

test)
    shift
    run_test "$@"
    ;;

deploy-operator)
    deploy_operator
    ;;

delete-cr)
    delete_cr
    ;;

*)
    echo "usage: $(basename "$0") { kind | deploy | test | deploy-operator | delete-cr }"
    ;;
esac

