PEM=~/spark-cluster.pem
KEY_NAME=spark-cluster
AMI=ami-7b048e08

./spark-ec2 -k $KEY_NAME -i $PEM -p exensa -s 1 -t m3.xlarge -r eu-west-1 -a $AMI --hadoop-major-version=yarn --ebs-vol-size=40 --spot-price=0.045 --spark-ec2-git-repo=https://github.com/dashcode/spark-ec2 --spark-ec2-git-branch=branch-1.6 launch cluster-with-amiv3
