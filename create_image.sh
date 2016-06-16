#!/bin/bash
# Creates an AMI for the Spark EC2 scripts starting with a stock Amazon 
# Linux AMI.
# This has only been tested with Amazon Linux AMI 2014.03.2 

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Dev tools
sudo yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel
sudo yum install -y gcc gcc-c++ ant git

# Perf tools
sudo yum install -y dstat iotop strace sysstat htop perf
sudo debuginfo-install -q -y glibc
sudo debuginfo-install -q -y kernel
sudo yum --enablerepo='*-debug*' install -q -y java-1.8.0-openjdk-debuginfo.x86_64

# Set java to java-1.8
alternatives --set java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java

# PySpark and MLlib deps
sudo yum install -y  python-matplotlib python-tornado scipy libgfortran

# Other handy tools
sudo yum install -y pssh

###
# eXenSa packets
###
sudo yum install -y zsh blas lapack blas-devel lapack-devel rsync xmlstarlet

pushd /tmp
aws s3 cp s3://wikipedia-exensa/mkl-redist.tgz .
tar zxf mkl-redist.tgz -C /usr/lib64
rm -f mkl-redist.tgz
popd

###
# Alternatives to use libmkl
##
alternatives --install /usr/lib64/libblas.so.3 libblas.so.3 /usr/lib64/libmkl_rt.so 100
alternatives --install /usr/lib64/libblas.so libblas.so /usr/lib64/libmkl_rt.so 100
alternatives --install /usr/lib64/libblas.so.3.5 libblas.so.3.5 /usr/lib64/libmkl_rt.so 100
alternatives --install /usr/lib64/libblas.so.3.5.0 libblas.so.3.5.0 /usr/lib64/libmkl_rt.so 100

alternatives --install /usr/lib64/liblapack.so.3 liblapack.so.3 /usr/lib64/libmkl_rt.so 100
alternatives --install /usr/lib64/liblapack.so liblapack.so /usr/lib64/libmkl_rt.so 100
alternatives --install /usr/lib64/liblapack.so.3.5 liblapack.so.3.5 /usr/lib64/libmkl_rt.so 100
alternatives --install /usr/lib64/liblapack.so.3.5.0 liblapack.so.3.5.0 /usr/lib64/libmkl_rt.so 100

alternatives --install /usr/lib64/liblapacke.so liblapacke.so /usr/lib64/libmkl_rt.so 100
alternatives --install /usr/lib64/liblapacke.so.3 liblapacke.so.3 /usr/lib64/libmkl_rt.so 100
alternatives --install /usr/lib64/liblapacke.so.3.5 liblapacke.so.3.5 /usr/lib64/libmkl_rt.so 100
alternatives --install /usr/lib64/liblapacke.so.3.5.0 liblapacke.so.3.5.0 /usr/lib64/libmkl_rt.so 100

# Root ssh config
sudo sed -i 's/PermitRootLogin.*/PermitRootLogin without-password/g' \
  /etc/ssh/sshd_config
sudo sed -i 's/disable_root.*/disable_root: 0/g' /etc/cloud/cloud.cfg

# Set up ephemeral mounts
sudo sed -i 's/mounts.*//g' /etc/cloud/cloud.cfg
sudo sed -i 's/.*ephemeral.*//g' /etc/cloud/cloud.cfg
sudo sed -i 's/.*swap.*//g' /etc/cloud/cloud.cfg

echo "mounts:" >> /etc/cloud/cloud.cfg
echo " - [ ephemeral0, /mnt, auto, \"defaults,noatime,nodiratime\", "\
  "\"0\", \"0\" ]" >> /etc/cloud.cloud.cfg

for x in {1..23}; do
  echo " - [ ephemeral$x, /mnt$((x + 1)), auto, "\
    "\"defaults,noatime,nodiratime\", \"0\", \"0\" ]" >> /etc/cloud/cloud.cfg
done

# Install Maven (for Hadoop)
pushd /tmp
wget "http://archive.apache.org/dist/maven/maven-3/3.2.3/binaries/apache-maven-3.2.3-bin.tar.gz"
tar xvzf apache-maven-3.2.3-bin.tar.gz
mv apache-maven-3.2.3 /opt/
rm -f apache-maven-3.2.3-bin.tar.gz
popd

# Edit bash profile
echo "export PS1=\"\\u@\\h \\W]\\$ \"" >> ~/.bash_profile
echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0" >> ~/.bash_profile
echo "export M2_HOME=/opt/apache-maven-3.2.3" >> ~/.bash_profile
echo "export PATH=\$PATH:\$M2_HOME/bin" >> ~/.bash_profile

source ~/.bash_profile

sudo yum install -y protobuf-compiler cmake openssl-devel

sudo yum install -y zlib-devel snappy-devel

echo '#!/bin/bash' > /usr/bin/realpath
echo 'readlink -e "$@"' >> /usr/bin/realpath
chmod a+x /usr/bin/realpath


###########################################################################################
### INSTALL ALL

###
# SPARK
###
echo "Starting Spark installation"
pushd /root
aws s3 cp s3://wikipedia-exensa/spark-1.6.1-bin-spark-1.6.1-lgpl.tgz .
tar -xf spark-1.6.1-bin-spark-1.6.1-lgpl.tgz
mv -f spark-1.6.1-bin-spark-1.6.1-lgpl /root/spark
rm -f spark-1.6.1-bin-spark-1.6.1-lgpl.tgz
popd


####
# Ephemeral HDFS
# Installation of Hadoop from source with Snappy.
###
pushd /tmp
wget "http://apache.crihan.fr/dist/hadoop/common/hadoop-2.7.2/hadoop-2.7.2-src.tar.gz"
tar xzf hadoop-2.7.2-src.tar.gz
cd hadoop-2.7.2-src
mvn clean package -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true -Drequire.snappy
mv -f hadoop-dist/target/hadoop-2.7.2 /root/ephemeral-hdfs
cd ..
rm -rf hadoop-2.7.2-src.tar.gz hadoop-2.7.2-src
ln -s /root/ephemeral-hdfs/etc/hadoop /root/ephemeral-hdfs/conf
cp -a /usr/lib64/libsnappy.so* /root/ephemeral-hdfs/lib/native/
popd

###
# SCALA INSTALLATION
###
echo "Starting Scala installation"
pushd /root > /dev/null
SCALA_VERSION="2.10.3"
echo "Unpacking Scala"
wget http://s3.amazonaws.com/spark-related-packages/scala-$SCALA_VERSION.tgz 
tar xvzf scala-*.tgz > /tmp/spark-ec2_scala.log
sudo rm scala-*.tgz
mv `ls -d scala-* | grep -v ec2` scala
popd > /dev/null
