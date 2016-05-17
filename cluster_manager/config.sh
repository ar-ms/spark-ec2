# ----------- CONFIG FOR EC2 ------------
NBSLAVES=1
INSTANCETYPE=m3.xlarge

export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
EC2_KEY=spark-cluster
EC2_REGION=eu-west-1

AMI=ami-5c4cd82f
SPOT_PRICE=0.045

installData_wikifr() {
    
    S3BUCKET=s3n://wikipedia-exensa/
    HDFS_DIR=/user/datasets

    # Warning target must be a file name and not a directory (because
    # the directory doesn't exists yet).
    s3ToHdfs ${S3BUCKET}/wikipedia-fr-2015 ${HDFS_DIR}/wikipedia-fr-2015
}
