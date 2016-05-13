PEM=~/spark-cluster.pem
KEY_NAME=spark-cluster
AMI=ami-4be67338
REGION=eu-west-1
CLUSTER_NAME=spark-cluster
EC2_TYPE=m3.xlarge
NB_SLAVES=2
EBS_VOLUME_SIZE=40
SPOT_PRICE=0.045

./spark-ec2 -k $KEY_NAME -i $PEM -p exensa -s $NB_SLAVES -t $EC2_TYPE -r $REGION -a $AMI --hadoop-major-version=yarn --ebs-vol-size=$EBS_VOLUME_SIZE --spot-price=$SPOT_PRICE --spark-ec2-git-repo=https://github.com/dashcode/spark-ec2 --spark-ec2-git-branch=branch-1.6 launch $CLUSTER_NAME
