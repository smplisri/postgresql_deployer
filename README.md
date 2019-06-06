# Postgresql Deployer script
This will fetch the content from the bitbucket location or github based on the configuration and the deploy the DDL/DMLs into postgresql

## Prerequisites - 
1. Install the PSQL into the machine prior to running this script.
2. Enable the SSH connection between the BitBucket/Github to the machine.
3. Setup the ${HOME}/.ssh/config with the appropriate host and it's alias and so on. Sample as below:
```shell
HOST GH_alias
   HostName github.com
   Port 7999
   IdentityFile ${HOME}/.ssh/github_proj.pem
```
4. Set the contents of the .ssh with the appropriate permissions.

## Usage information of the script
```
Syntax: $scriptname -a <BitBucket/Github host alias> -j <BitBucket/Github project name> [-h <Postgres host>] [-p <Postgres port>] [-d <Postgres database>] [-b <BitBucket/Github branch>] [-s <Subdirectory>] [-w <Vertica password>] <BitBucket/Github repo> <File name>

			-a : **Required** The host alias name mentioned in the config file in the .ssh location.
			-j : **Required** The project/name of user under where the repository is present that holds the DMLs/DDLs.
			-h : Provide the host name for the Postgres database if it is other than localhost.
			-p : Provide the port for the postgres if it is other than 5432.
			-d : Provide the database name if there is any.
			-b : Provide the branch name from where the DDLs and the DMLs are to be retrieved. If not provided, the script will try to look for the DDLs and DMLs in the master branch.
			-w : Provide the password for the database connection. If not provided the script will prompt for the password.
			-s : Subdirectories if any within the branch where the DDLs and DMLs are placed.
```

The script takes the repository name and file name as the required parameters. Also, please make sure that the machine is able to talk to the BitBucket/Github directly using the SSH access keys. Further information is present in the following URL link on how to use the SSH keys to connect to the BitBucket/Github.

**BitBucket -** [https://confluence.atlassian.com/bitbucket/set-up-an-ssh-key-728138079.html](https://confluence.atlassian.com/bitbucket/set-up-an-ssh-key-728138079.html)
			
**Github -** [https://help.github.com/en/articles/about-ssh](https://help.github.com/en/articles/about-ssh)

```shell
# Example for execution of the script - 
sh /<script_location>/psql_deployer.sh -a ${Bitbucket/Github host alias} -h ${Postgresql host} -d ${Postgresql database} -u ${Postgresql user} -w ${Postgresql password} -b ${BitBucket/Github repository branch} -s ${BitBucket/Github subfolder} ${BitBucket/Github repository} <DML/DDL script name>
```
