#!/bin/bash
#
# Terminate cluster
#

export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/ec2-base.sh

echo y | ../spark-ec2 -k ${EC2_KEY} -i $PEM --region ${EC2_REGION} --delete-groups destroy ${CLUSTER_NAME}
