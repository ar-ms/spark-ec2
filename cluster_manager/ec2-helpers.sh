s3ToHdfs() {
	${ONMASTER} ${HADOOPBINONMASTER}"/hadoop distcp -Dfs.s3n.awsAccessKeyId=$AWS_ACCESS_KEY_ID -Dfs.s3n.awsSecretAccessKey=$AWS_SECRET_ACCESS_KEY $1 $2"	
}

deleteIfExists() {
	if [[ -d $1 ]]
	then
		rm -rf $1
	fi
}

replaceCurrentResults() {
	CUR=$1
	NEW=$2
	OLD=${CUR}.old

	deleteIfExists $OLD
	mv $CUR $OLD
	mv $NEW $CUR
}

retrieveNewResults() {
	HDFSPATH=$1
	NEWBINFILES=$2

	deleteIfExists $NEWBINFILES
	mkdir $NEWBINFILES

	rsync -rave "ssh -i ${PEM}" root@${MASTER}:${HDFSPATH} ${NEWBINFILES}
}

notEmpty() {
	DIR_TO_TEST=$1

	if [ "$(ls -A $DIR_TO_TEST)" ]; then
		true
	else
		false
	fi
}

fn_exists() {
    type $1 | grep -q 'function'
}

checkFunctions() {

    fn_exists installData_${CLUSTER_NAME} || {
	echo "function installData_${CLUSTER_NAME} must be define in config.sh"
	#exit 1
    }
}
