#! /usr/bin/env bash

set -uex
set -o pipefail

CLUSTER=dask
EXISTS=$(eksctl get cluster --region us-east-2 | grep "$CLUSTER" || echo -n "Not found")

if [ "$EXISTS" == "Not found" ]; then
    # create cluster with fargate backend
    eksctl create cluster \
	--name $CLUSTER \
	--tags "Owner=ivan,Purpose=laion,Via=eksctl,Type=fargate" \
	--fargate \
	--set-kubeconfig-context \
	--region us-east-2
    # enable iam role provider for k8s service accounts on cluster
    eksctl utils associate-iam-oidc-provider \
	    --cluster $CLUSTER \
	    --approve \
	    --region us-east-2
    # create a service account for dask workers
    eksctl create iamserviceaccount \
        --name dask-worker \
        --namespace default \
        --cluster $CLUSTER \
        --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
        --approve \
        --override-existing-serviceaccounts \
        --region us-east-2
fi

VPC_ID=`eksctl get cluster --region us-east-2 --name dask -o json | jq -r '.[].ResourcesVpcConfig.VpcId'`
export TF_VAR_vpc_id=$VPC_ID

terraform init
terraform apply
