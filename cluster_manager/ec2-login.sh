#!/bin/sh

if [ -z ${1} ];
then
    echo "Usage: "$0" cluster_name"
    exit 1
fi

#
# allows to connect and get a shell on the cluster
#

export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/ec2-base.sh

# login on cluster
../spark-ec2 -k ${EC2_KEY} -i $PEM --region ${EC2_REGION} login ${CLUSTER_NAME}
