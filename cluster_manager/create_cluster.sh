#!/bin/bash
#
# Launch cluster
#

APP_TGZ=$1
shift

export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/ec2-base.sh

echo $APP_TGZ
echo $CLUSTER_NAME

../spark-ec2 -k $EC2_KEY -i $PEM -s $NBSLAVES -t $INSTANCETYPE -r $EC2_REGION -a $AMI --hadoop-major-version=yarn --spot-price=$SPOT_PRICE \
    --spark-ec2-git-repo=https://github.com/dashcode/spark-ec2 --spark-ec2-git-branch=branch-1.6 launch $CLUSTER_NAME


export MASTER=$( ../spark-ec2 -k ${EC2_KEY} -i $PEM --region ${EC2_REGION} get-master $CLUSTER_NAME | grep amazonaws )

export ONMASTER="ssh -o StrictHostKeyChecking=no -i $PEM root@${MASTER}"

# set spark environment variables                                                                                    
echo 'export SPARK_JAVA_OPTS="$SPARK_JAVA_OPTS -XX:+UseCompressedOops -XX:+UseParallelGC -Dspark.worker.timeout=200 -Dspark.akka.askTimeout=200 -Dspark.akka.timeout=200 -Dspark.shuffle.consolidateFiles=true"' | $ONMASTER "cat >> ${SPARKON\
MASTER}/conf/spark-env.sh"
echo 'export SPARK_DAEMON_MEMORY=1g' | $ONMASTER "cat >> ${SPARKONMASTER}/conf/spark-env.sh"
echo 'export SPARK_DAEMON_JAVA_OPTS="-Dspark.worker.timeout=200 -Dspark.akka.askTimeout=200 -Dspark.akka.timeout=200 -Dspark.shuffle.consolidateFiles=true"' | $ONMASTER "cat >> ${SPARKONMASTER}/conf/spark-env.sh"
$ONMASTER spark-ec2/copy-dir ${SPARKONMASTER}/conf/spark-env.sh

# here verify that application is really on only one place.                                                          
scp -i $PEM ${APP_TGZ} root@${MASTER}:
$ONMASTER tar zxf $(basename ${APP_TGZ})

# alter xml workflow configuration with spark master                                                                 
$ONMASTER xmlstarlet ed -L --update "/configuration/spark/master" --value ${MASTER} ${APP_ON_MASTER}/config/workflow/env.xml

$ONMASTER cp ${HADOOPONMASTER}/conf/core-site.xml ${APP_ON_MASTER}/
$ONMASTER cp ${HADOOPONMASTER}/conf/hdfs-site.xml ${APP_ON_MASTER}/
# tmp directory for spark ?                                                                                          
$ONMASTER mkdir /mnt/spark
# create directory where binfiles are dump                                                                           
$ONMASTER mkdir /mnt/data
$ONMASTER ln -s /mnt/data /data

##### copy data from S3                                                                                              
echo "Copying data..."
installData_${CLUSTER_NAME}

##### launch workflow                                                                                                
$ONMASTER "cd ${APP_ON_MASTER}; ./workflow_${CLUSTER_NAME}.sh"
