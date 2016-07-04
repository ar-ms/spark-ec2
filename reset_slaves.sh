#!/bin/bash

# usage: echo_time_diff name start_time end_time
echo_time_diff () {
  local format='%Hh %Mm %Ss'

  local diff_secs="$(($3-$2))"
  echo "[timing] $1: " "$(date -u -d@"$diff_secs" +"$format")"
}

# Make sure we are in the spark-ec2 directory
pushd /root/spark-ec2 > /dev/null

# Load the environment variables specific to this AMI
source /root/.bash_profile

# Load the cluster variables set by the deploy script
source ec2-variables.sh

echo "$SLAVES" > slaves

SLAVES=`cat slaves`
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

echo "RSYNC'ing /root/spark-ec2 to other cluster nodes..."
rsync_start_time="$(date +'%s')"
for node in $SLAVES $OTHER_MASTERS; do
  echo $node
  rsync -e "ssh $SSH_OPTS" -az /root/spark-ec2 $node:/root &
  sleep 0.1
done
wait
rsync_end_time="$(date +'%s')"
echo_time_diff "rsync /root/spark-ec2" "$rsync_start_time" "$rsync_end_time"

popd > /dev/null

pushd /root > /dev/null

ROOT_DIR="/root/"
MAPRED_CONF_DIR="$ROOT_DIR/mapreduce/conf"
EP_EPHEMERAL_CONF_DIR="$ROOT_DIR/ephemeral-hdfs/etc/hadoop"
PE_EPHEMERAL_CONF_DIR="$ROOT_DIR/persistent-hdfs/conf"
TACHYON_CONF_DIR="$ROOT_DIR/tachyon/conf"
SPARK_CONF_DIR="$ROOT_DIR/spark/conf"

if [ -d $MAPRED_CONF_DIR ]; then
    cat /root/spark-ec2/slaves > $MAPRED_CONF_DIR/slaves
fi

if [ -d $EP_EPHEMERAL_CONF_DIR ]; then
    cat /root/spark-ec2/slaves > $EP_EPHEMERAL_CONF_DIR/slaves
fi

if [ -d $PE_EPHEMERAL_CONF_DIR ]; then
    cat /root/spark-ec2/slaves > $PE_EPHEMERAL_CONF_DIR/slaves
fi

if [ -d $MAPRED_CONF_DIR ]; then
    cat /root/spark-ec2/slaves > $TACHYON_CONF_DIR/slaves
fi

if [ -d $SPARK_CONF_DIR ]; then
    cat /root/spark-ec2/slaves > $SPARK_CONF_DIR/slaves
fi

popd > /dev/null
