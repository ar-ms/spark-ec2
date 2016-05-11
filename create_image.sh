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
sudo yum install -y java-1.8.0-openjdk-devel gcc gcc-c++ ant git

# Perf tools
sudo yum install -y dstat iotop strace sysstat htop perf
sudo debuginfo-install -q -y glibc
sudo debuginfo-install -q -y kernel
sudo yum --enablerepo='*-debug*' install -q -y java-1.8.0-openjdk-debuginfo.x86_64

# PySpark and MLlib deps
sudo yum install -y  python-matplotlib python-tornado scipy libgfortran
# SparkR deps
sudo yum install -y R
# Other handy tools
sudo yum install -y pssh
# Ganglia
sudo yum install -y ganglia ganglia-web ganglia-gmond ganglia-gmetad

## TODO: CHECKING FOR .AWS FOLDER

###
# eXenSa packets
sudo yum install -y zsh blas lapack rsync xmlstarlet
aws s3 cp s3://exensa/mkl-redist.tgz .
sudo tar zxf mkl-redist.tgz -C /usr/lib

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
cd /tmp
wget "http://archive.apache.org/dist/maven/maven-3/3.2.3/binaries/apache-maven-3.2.3-bin.tar.gz"
tar xvzf apache-maven-3.2.3-bin.tar.gz
mv apache-maven-3.2.3 /opt/

# Edit bash profile
echo "export PS1=\"\\u@\\h \\W]\\$ \"" >> ~/.bash_profile
echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0" >> ~/.bash_profile
echo "export M2_HOME=/opt/apache-maven-3.2.3" >> ~/.bash_profile
echo "export PATH=\$PATH:\$M2_HOME/bin" >> ~/.bash_profile

source ~/.bash_profile

# Build Hadoop to install native libs
sudo mkdir /root/hadoop-native
cd /tmp
sudo yum install -y protobuf-compiler cmake openssl-devel
# wget "http://archive.apache.org/dist/hadoop/common/hadoop-2.4.1/hadoop-2.4.1-src.tar.gz"
wget "http://archive.apache.org/dist/hadoop/common/hadoop-2.6.4/hadoop-2.6.4-src.tar.gz"
tar xvzf hadoop-2.6.4-src.tar.gz
cd hadoop-2.6.4-src
mvn clean package -Pdist,native -DskipTests -Dtar -Dmaven.javadoc.skip=true
sudo mv hadoop-dist/target/hadoop-2.6.4/lib/native/* /root/hadoop-native

# Install Snappy lib (for Hadoop)
yum install -y snappy
ln -sf /usr/lib64/libsnappy.so.1 /root/hadoop-native/.

# Create /usr/bin/realpath which is used by R to find Java installations
# NOTE: /usr/bin/realpath is missing in CentOS AMIs. See
# http://superuser.com/questions/771104/usr-bin-realpath-not-found-in-centos-6-5
echo '#!/bin/bash' > /usr/bin/realpath
echo 'readlink -e "$@"' >> /usr/bin/realpath
chmod a+x /usr/bin/realpath


###########################################################################################
### INSTALL ALL

###
# SPARK
echo "Starting Spark installation"
cd /tmp
aws s3 cp s3://exensa/spark-1.6.1-bin-spark-1.6.1-lgpl.tgz .
tar -xf spark-1.6.1-bin-spark-1.6.1-lgpl.tgz
sudo mv spark-1.6.1-bin-spark-1.6.1-lgpl /root/spark
sudo rm spark-1.6.1-bin-spark-1.6.1-lgpl.tgz

###
# Persistent HDFS
echo "Starting persistent HDFS installation"
pushd /root > /dev/null
wget http://s3.amazonaws.com/spark-related-packages/hadoop-2.4.0.tar.gz
echo "Unpacking Hadoop"
tar xvzf hadoop-*.tar.gz > /tmp/spark-ec2_hadoop.log
rm hadoop-*.tar.gz
mv hadoop-2.4.0/ persistent-hdfs/
# Have single conf dir
rm -rf /root/persistent-hdfs/etc/hadoop/
ln -s /root/persistent-hdfs/conf /root/persistent-hdfs/etc/hadoop
popd > /dev/null

####
# Ephemeral HDFS
echo "Starting Ephemeral HDFS installation"
pushd /root > /dev/null
wget http://s3.amazonaws.com/spark-related-packages/hadoop-2.4.0.tar.gz
echo "Unpacking Hadoop"
tar xvzf hadoop-*.tar.gz > /tmp/spark-ec2_hadoop.log
rm hadoop-*.tar.gz
mv hadoop-2.4.0/ ephemeral-hdfs/
# Have single conf dir
rm -rf /root/ephemeral-hdfs/etc/hadoop/
ln -s /root/ephemeral-hdfs/conf /root/ephemeral-hdfs/etc/hadoop
popd > /dev/null

####
# SCALA INSTALLATION
echo "Starting Scala installation"
pushd /root > /dev/null
SCALA_VERSION="2.10.3"
echo "Unpacking Scala"
wget http://s3.amazonaws.com/spark-related-packages/scala-$SCALA_VERSION.tgz 
tar xvzf scala-*.tgz > /tmp/spark-ec2_scala.log
sudo rm scala-*.tgz
mv `ls -d scala-* | grep -v ec2` scala
popd > /dev/null


# Ganglia
echo "Starting Ganglia installation"
# NOTE: Remove all rrds which might be around from an earlier run
rm -rf /var/lib/ganglia/rrds/*
rm -rf /mnt/ganglia/rrds/*
# Make sure rrd storage directory has right permissions
mkdir -p /mnt/ganglia/rrds
chown -R nobody:nobody /mnt/ganglia/rrds
# Install ganglia
# TODO: Remove this once the AMI has ganglia by default
# Post-package installation : Symlink /var/lib/ganglia/rrds to /mnt/ganglia/rrds
rmdir /var/lib/ganglia/rrds
ln -s /mnt/ganglia/rrds /var/lib/ganglia/rrds
