#!/bin/sh

##################################################################################################
# Name - psql_deployer.sh
# Description - This script will be able to pull the DDLs and DMLs from the BitBucket and then
#  execute the underlying statements in postgres. The DDLs and DMLs has to be placed in proper
#  format and file names for this script to run without issues.
#
# Prerequisites - 
#		1. Install the PSQL into the machine prior to running this script.
#		2. Enable the SSH connection between the BitBucket/Github to the machine.
#		3. Setup the ${HOME}/.ssh/config with the appropriate host and it's alias and so on. Sample as below:
#			HOST GH_alias
#				HostName github.com
#				Port 7999
#				IdentityFile ${HOME}/.ssh/github_proj.pem
#			
# Author - Kalyan
# Date created - 04/05/2019
#
##################################################################################################

debug=0

scriptname=`basename $0`
scriptlocation=`echo $0 | sed 's/'$scriptname'//g' | sed 's/^$/\./g'`

echo "Move into the script location and then set the absolute path for the script location"
cd ${scriptlocation}
if [ $? -ne 0 ]; then
	echo "Error in moving into the script location"
	exit 1
fi

scriptlocation=`pwd`"/"

LOGS=${scriptlocation}"logdir"
if [ ! -e ${LOGS} ]; then
	mkdir -p ${LOGS}
fi
#------------------------------#
# function to display the usage of the script whenever the appropriate parameters are not passed in as expected #
#------------------------------#

usage() {
	cat <<- EOF >&2
			Usage: $scriptname -a <BitBucket/Github host alias> -j <BitBucket/Github project name> [-h <Postgres host>] [-p <Postgres port>] [-d <Postgres database>] [-b <BitBucket/Github branch>] [-s <Subdirectory>] [-w <Vertica password>] <BitBucket/Github repo> <File name>
			
			-a : **Required** The host alias name mentioned in the config file in the .ssh location.
			-h : Provide the host name for the Postgres database if it is other than localhost.
			-p : Provide the port for the postgres if it is other than 5432.
			-d : Provide the database name if there is any.
			-b : Provide the branch name from where the DDLs and the DMLs are to be retrieved. If not provided, the script will try to look for the DDLs and DMLs in the master branch.
			-w : Provide the password for the database connection. If not provided the script will prompt for the password.
			-s : Subdirectories if any within the branch where the DDLs and DMLs are placed.
			
			The script takes the repository name and file name as the required parameters. Also, please make sure that the EMR is able to talk to the BitBucket/Github directly using the SSH access keys. Further information is present in the following URL link on how to use the SSH keys to connect to the BitBucket/Github.
			
			BitBucket -
			https://confluence.atlassian.com/bitbucket/set-up-an-ssh-key-728138079.html
			
			Github -
			https://help.github.com/en/articles/about-ssh
	EOF
	exit 1
}

#------------------------------#
# Initializing the options as required #
#------------------------------#
BB_host_alias=""
BB_project=""
BB_branch="master"
BB_subdir=""
PG_host="localhost"
PG_port="5432"
PG_database=""
PG_user=""
PG_password=""

while getopts "a:j:e:b:d:h:p:s:u:w:" o; do
	case "$o" in
		a) BB_host_alias=$OPTARG;;
		j) BB_project=$OPTARG;;
		b) BB_branch=$OPTARG;;
		s) BB_subdir=$OPTARG;;
		h) PG_host=$OPTARG;;
		p) PG_port=$OPTARG;;
		d) PG_database=$OPTARG;;
		u) PG_user=$OPTARG;;
		w) PG_password=$OPTARG;;
		\?) usage;;
	esac
done
shift "$((OPTIND - 1))"

#------------------------------#
# Setting the log file name to log every information from the script #
#------------------------------#

Log_tm=`date +'%Y%m%d_%H%M%S'`
Log_file=${scriptname}_${1}_${Log_tm}.log
if [[ ! -e ${scriptlocation}/logdir ]]; then
	mkdir -p ${scriptlocation}/logdir
fi
LOGS=${scriptlocation}/logdir

#------------------------------#
# function to load the log file and then display the same on to console #
#------------------------------#

function logfile {
	log_msg=$1
	log_tm=`date +'%m-%d-%Y %H:%M:%S'`
	echo $log_msg
	echo $log_msg $log_tm >> $LOGS/$Log_file
}

#------------------------------#
# Script execution to process the postgres deployment #
#------------------------------#

logfile "Start with the execution of the script"
logfile "Checking for the required parameters"
if [ $# -ne 2 ]; then
	logfile "#######################################################################################"
	logfile "ERROR: Not all the required parameters are provided."
	logfile "#######################################################################################"
	logfile "#######################################################################################"
	logfile "#######################################################################################"
	usage
	logfile "Please rerun the script with appropriate parameters."
fi

BB_repo_nm=$1
BB_file_nm=$2

git ls-remote -q -h ssh://git@${BB_host_alias}/${BB_project}/${BB_repo_nm}.git
rc=$?
if [ $rc -eq 128 ]; then
	logfile "ERROR: Please make sure the appropriate access are present by following the below mentioned checklist"
	logfile "1. Make sure the Github/Bitbucket alias is set with the process redirection to the Github/BitBucket host"
	logfile "2. Make sure that the Github/BitBucket has process SSH key mentioned in it and also the pem file is present in the machine with proper info in the config file"
	logfile "3. Make sure the repository is present in the Github/BitBucket under the project folder"
	exit 1
elif [ $rc -eq 0 ]; then
	logfile "Success in connecting to the Github/BitBucket repository"
else
	logfile "ERROR: Error in running the git command to list the repository as part of the verification process"
	exit 1
fi

logfile "Creating the sub directory for the repository - ${BB_repo_nm}"
git init ${scriptlocation}${BB_repo_nm}_${BB_branch}_${Log_tm}
if [ $? -ne 0 ]; then
	logfile "ERROR: Unable to initiate an empty repository"
	exit 1
fi

cd ${scriptlocation}${BB_repo_nm}_${BB_branch}_${Log_tm}
if [ $? -ne 0 ]; then
	logfile "ERROR: Problem in changing into the newly initiated ${scriptlocation}${BB_repo_nm}_${BB_branch}_${Log_tm} directory"
fi

logfile "Setting the appropriate configurations"
git config remote.origin.url ssh://git@${BB_host_alias}/${BB_project}/${BB_repo_nm}.git
if [ $? -ne 0 ]; then
	logfile "ERROR: Error in configuring remote.origin.url"
	cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}
	exit 1
fi

git config --add remote.origin.fetch +refs/heads/*:refs/remotes/origin/*
if [ $? -ne 0 ]; then
	logfile "ERROR: Error in configuring remote.origin.fetch"
	cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}
	exit 1
fi

logfile "Fetching all the changes from the repository"
git fetch --tags --progress ssh://git@${BB_host_alias}/${BB_project}/${BB_repo_nm}.git +refs/heads/*:refs/remotes/origin/*
if [ $? -ne 0 ]; then
	logfile "ERROR: Error in fetching the repository"
	cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}
	exit 1
fi

parser=`git rev-parse refs/remotes/origin/${BB_branch}^{commit}`
if [ $? -ne 0 ]; then
	logfile "ERROR: Issue in parsing the branch"
	logfile "Please make sure the branch ${BB_branch} is available in the repository"
	cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}
	exit 1
fi

git config core.core.sparseCheckout true
if [ $? -ne 0 ]; then
	logfile "ERROR: Error in configuring core.sparseCheckout"
	cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}
	exit 1
fi

logfile "Checking out the ${parser} from the BitBucket to read the required objects"
git checkout -f ${parser}
if [ $? -ne 0 ]; then
	logfile "Error in checking out the ${parser} commit version of the code"
	cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}
	exit 1
fi

logfile "Start the deployment of the ${BB_file_nm} from the ${BB_subdir} in the ${BB_branch} branch from the ${BB_repo_nm} repository"
if [ -e ./${BB_subdir}/${BB_file_nm} ]; then
	if [[ $- =~ x ]]; then debug=1; set +x; fi
		if [[ ${PG_password} != "" ]]; then
			psql -v ON_ERROR_STOP=1 -w -a -f ./${BB_subdir}/${BB_file_nm} --log-file=${LOGS}/psql_${Log_file} postgresql://${PG_user}:${PG_password}@${PG_host}:${PG_port}/${PG_database}
			rc=$?
		else
			psql -v ON_ERROR_STOP=1 -W -a -f ./${BB_subdir}/${BB_file_nm} --log-file=${LOGS}/psql_${Log_file} postgresql://${PG_user}@${PG_host}:${PG_port}/${PG_database}
			rc=$?
		fi
	[[ $debug == 1 ]] && set -x
	if [ $rc -eq 127 ]; then
		logfile "ERROR: Error in finding the psql command. Please install the appropriate psql using the yum install and then try this script"
		cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}
		exit 1
	elif [ $rc -eq 0 ]; then
		logfile "Successfully completed the postgres sql deployment for the ${BB_file_nm}"
	else
		logfile "ERROR: Error in the psql. Please check the ${LOGS}/psql_${Log_file} file for more information"
		cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}
		exit 1
	fi
else
	logfile "Error in finding the file ${BB_file_nm}. Please validate and rerun the script"
	cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}
	exit 1
fi

logfile "Cleanup the local repository"
cd ${scriptlocation} && rm -rf ${BB_repo_nm}_${BB_branch}_${Log_tm}

exit 0
