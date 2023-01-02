#! /usr/bin/env bash

set -eux

helm repo add dask https://helm.dask.org
helm repo update
helm upgrade -i -f values.yaml dask dask/dask --wait --timeout 300s

export DASK_SCHEDULER="127.0.0.1"
export DASK_SCHEDULER_UI_IP="127.0.0.1"
export DASK_SCHEDULER_PORT=8080
export DASK_SCHEDULER_UI_PORT=8081
export DASK_SCHEDULER_ADDRESS="127.0.0.1:8080"

kubectl port-forward --namespace default svc/dask-scheduler $DASK_SCHEDULER_PORT:8786 &
kubectl port-forward --namespace default svc/dask-scheduler $DASK_SCHEDULER_UI_PORT:80 &

echo tcp://$DASK_SCHEDULER:$DASK_SCHEDULER_PORT               -- Dask Client connection
echo http://$DASK_SCHEDULER_UI_IP:$DASK_SCHEDULER_UI_PORT     -- Dask dashboard


