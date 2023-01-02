#!/bin/bash

BOOTSTRAP_LOCATION=s3://dvc-private/laion/bootstrap

aws s3 cp $BOOTSTRAP_LOCATION/img2dataset.pex /home/hadoop/img2dataset.pex
chmod +x /home/hadoop/img2dataset.pex

if grep isMaster /mnt/var/lib/info/instance.json | grep true;
then
    aws s3 cp $BOOTSTRAP_LOCATION/download.py /home/hadoop/download.py
fi

sudo yum update -y
sudo yum install git -y
sudo amazon-linux-extras install epel -y
yum-config-manager --enable epel
sudo yum update -y

# Monitoring tools
sudo yum install iftop bwm-ng htop -y

# Speedups DNS, it bumps perf 2x+
sudo yum install knot-resolver -y
echo "internalDomains = policy.todnames({'us-east-2.compute.internal', 'in-addr.arpa'})" | sudo tee -a /etc/knot-resolver/kresd.conf
echo "policy.add(policy.suffix(policy.FLAGS({'NO_CACHE'}), internalDomains))" | sudo tee -a /etc/knot-resolver/kresd.conf
echo "policy.add(policy.suffix(policy.STUB({'172.31.0.2'}), internalDomains))" | sudo tee -a /etc/knot-resolver/kresd.conf
sudo systemctl start kresd@{1..4}.service

echo "supersede domain-name-servers 127.0.0.1;" | sudo tee -a /etc/dhcp/dhclient.conf
echo "search us-east-2.compute.internal" | sudo tee /etc/resolv.conf
echo "nameserver 127.0.0.1" | sudo tee -a /etc/resolv.conf

