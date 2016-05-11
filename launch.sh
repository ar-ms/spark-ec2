PEM=~/KEY.pem
KEY_NAME=NAME

./spark-ec2 -k $KEY_NAME -i $PEM -p exensa -s 1 -t m3.xlarge -r eu-west-1 -a ami-a3de54d0 --hadoop-major-version=2 --worker-instances=2 --ebs-vol-size=40 --spot-price=0.045 --spark-ec2-git-repo=https://github.com/dashcode/spark-ec2 --spark-ec2-git-branch=branch-1.6 launch cluster-with-amiv2
