if [[ -z $1 ]]
then
    echo "No cluster name specified, using \"default\""
    CLUSTER_NAME=default
else
    CLUSTER_NAME=$1
fi

#. ${COMMON}/env.sh
. ${DIR}/ec2-helpers.sh

# load configuration to connect on EC2 and S3

APP_HOME=$DIR
echo "source ${APP_HOME}/config.sh"
. ${APP_HOME}/config.sh
PEM=${APP_HOME}/keys/${EC2_KEY}.pem

checkFunctions

# on the master, SPARKONMASTER should match env.xml configuration

HADOOPONMASTER=/root/ephemeral-hdfs/
HADOOPBINONMASTER=${HADOOPONMASTER}/bin/
SPARKONMASTER=/root/spark
SCALAONMASTER=/root/scala
APP_ON_MASTER=/root/workflow
