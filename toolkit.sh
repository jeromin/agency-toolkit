#!/bin/bash
#
# @Weedo.Agency toolkit
# Jeromin <me@jeromin.fr>

set -e

NAME=$(basename "${BASH_SOURCE[0]}")
source_file="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )/$NAME"
vars_file="$HOME/.$NAME"
# vars_file="$HOME/.weedo-test"
command_path="/usr/local/bin/"
log_file="$HOME/$NAME.log"

output(){
	# Usage : output [-c blue] [-s bold] string
    # -c color	: Text color 
    # -b color	: Background color 
    # -s style	: Text style
    # -e 		: Error style
    # -n 		: New line
    # -h 		: Header style
	color="39"; bgcolor="49"; style="0";
	local OPTIND
	while getopts "c:b:s:enh" option
	do
	    case $option in
		c) case $OPTARG in
			"red") color="31";; "green") color="32";; "yellow") color="33";; "blue") color="34";; "magenta") color="35";; "lightblue") color="36";;
			esac;;
		b)  local bg=1; case $OPTARG in
			"red") bgcolor="41";; "blue") bgcolor="44";; "pink") bgcolor="45";; "lightblue") bgcolor="46";;
			esac;;
		s)  case $OPTARG in
			"normal") style="0";; "bold") style="1"; if ((color=="39"));then color="36"; fi;; "underline") style="4";; "blink") style="1;5";;
			esac;;
		n)	local newline="\n";;
		h)  local block="1";;
		e)	local error="1";;
	    esac
	done
	message=${@:$OPTIND:1};
	if [[ $error == "1" ]]; then message="\n🚨 $message\n"; fi
	if [[ $bg == "1" ]]; then message=" $message "; fi
	if [[ $block == "1" ]]; then
		message=$(
			echo "\n----------------------------------------"
			echo "    $message"
			echo "----------------------------------------\n")
		message="\e[$style;$bgcolor;${color}m$message\e[m"
	else
		message=" \e[$style;$bgcolor;${color}m$message\e[m"
	fi
	printf "${message}$newline"
}

usage(){
	# local
	CMD=$([[ "$NAME" =~ ".sh" ]] && echo "./$NAME" || echo "$NAME")
	output -c magenta -n "Weedo.Agency backup toolkit."; output -n
    output -c magenta -s bold -n "Usage:"
    output -n "$CMD ls|list [site]"
    output -n "$CMD backup [disk|mysql] site"
    output -n "$CMD connect site"
    output -n "$CMD run site command"
    output -n "$CMD bucket [site]"
    output -n "$CMD key create|copy [site|key user@remote]"
    output -n "$CMD test [disk|mysql] site"
    output -n "$CMD link|unlink [name]"
    output -n "$CMD configure|log|help"
    exit
}
finish(){
	if [ $? = 1 ]; then
		output -n "☠️ \x20 The script did not terminated well."
	fi
}
trap finish QUIT EXIT

newWebsite(){
	read -p "Name (ID) of the website : " name

	if [ $name ]; then
		readonly "$name"=$name; if [ $? -eq 1 ]; then
			output -n -s bold "This ID can't be used as a variable, sorry."; exit; fi
		read -p "SSH hostname : " ssh_hostname; fi
	if [ $ssh_hostname ]; then 
		read -p "SSH user : " ssh_user; fi
	if [ $ssh_user ]; then
		read -p "Do you need to create an SSH key ? [y/n] " create
		if [ $create ] && [ $create == "y" ]; then
			createKey $ssh_user@$ssh_hostname
			ssh_key=$ssh_key_path
		else
			read -p "SSH key path : " ssh_key
		fi
	fi
	if [ $ssh_key ]; then 
		read -p "Remote folder path : " remote_dir; fi
	if [ $remote_dir ]; then
		read -p "Which transfer protocol will you use [ssh|sftp] ? " protocol
	fi
	if [ $protocol ]; then
		read -p "Do you want to add a MySql databse to backup ? [y/n] " mysql
	fi
	if [ $protocol == "sftp" ] && [ mysql == "y" ]; then
		read -p "Mysql backup will done over HTTP, specify the website url [ default http://${ssh_hostname#[[:alpha:]]*.} ] " url
	fi
	if [ $mysql ] && [ $mysql == "y" ]; then
		read -p "MySql host [default localhost] : " mysql_host
		read -p "MySql user : " mysql_user
		read -p "MySql database : " mysql_db
		read -p "MySql password : " mysql_pwd
		read -p "MySql port [default 3306] : " mysql_port
	fi

	if [ $name ] && [ $ssh_hostname ] && [ $ssh_user ] && [ $ssh_key ] && [ $remote_dir ]; then
		echo >> "$vars_file"

		echo ${name}_ssh_hostname=$ssh_hostname >> $vars_file
		echo ${name}_ssh_user=$ssh_user >> $vars_file
		echo ${name}_ssh_key=$ssh_key >> $vars_file
		echo ${name}_remote_dir=$remote_dir >> $vars_file

		if [[ $protocol == "sftp" ]]; then
			echo ${name}_protocol=$protocol >> $vars_file; fi

		if [ $url ]; then
			echo ${name}_url=$url >> $vars_file; fi

		if [ $mysql_user ] && [ $mysql_db ] && [ $mysql_pwd ];then
			if [ $mysql_host ] && [ $mysql_host != 'localhost'  ]; then
				echo ${name}_mysql_host=$mysql_host >> $vars_file; fi
			if [ $mysql_port ] && [ $mysql_port != '3306'  ]; then
				echo ${name}_mysql_pwd=$mysql_port >> $vars_file; fi
			echo ${name}_mysql_user=$mysql_user >> $vars_file
			echo ${name}_mysql_db=$mysql_db >> $vars_file
			echo ${name}_mysql_pwd=$mysql_pwd >> $vars_file
		fi
		
		output "Site"; output -s bold "$name"; output -n "created."
	fi
}
configureBucket(){
	read -p "Which provider do you want to use as Bucket ? [gsutil/aws/s3cmd] " provider
	if [ $provider ]; then
		echo "bucket_provider=$provider" >> $vars_file
		read -p "Type your bucket name, or leave empty to use script name [$NAME] " bucket_name		
		
		if [ -z $bucket_name ]; then
			$bucket_name=$NAME; fi
			
		echo "bucket_name=$bucket_name" >> $vars_file
	else exit; fi
}
setup(){
	output -h "⚙️ \x20 Let's begin setting up .."

	configureBucket

	read -p "How many website do you want to set up [default 1] ? " number
	number=${number:-1}
	for (( i = 0; i < number; i++ )); do
		newWebsite;	done

	output -n "\n🍻 Configuration done. We're ready to backup."
	usage
}
checkConfig(){
	if [ -f "$vars_file" ]; then
		for line in $(awk -F= '{print $1}' "$vars_file"); do
			if [ "${line:0:1}" != "#" ]; then
				readonly "${line}"=$(awk -F= '$1=="'$line'"{print $2}' "$vars_file")
				IFS='_' read -r -a array <<< "${line}"
				if [[ ${array[2]} == "hostname" ]]; then sites+=(${array[0]}); fi
			fi
		done

		bucketConfig

		if [ ${#sites[@]} -eq 0 ]; then
			output -n "No website configuration found."
			read -p "Do you want to set up now ? [y/n] " answer
			if [ $answer ] && [ $answer == "y" ]; then newWebsite
			else exit; fi
		fi

	else
		output -n "No configuration file found."
		read -p "Do you want to set ip up now ? [y/n] " answer
		if [ $answer ] && [ $answer == "y" ]; then setup
		else exit; fi
	fi
}
envSetup(){
	checkConfig

	if [ -z $1 ]; then
		output -n -e "Site name is expected."; usage; exit
	else 
		site=$1;
		ssh_hostname="${site}_ssh_hostname"; ssh_hostname=${!ssh_hostname}

		if [ -z $ssh_hostname ]; then
			output -n -e "Site name is not correct."; usage; exit; fi

		ssh_user="${site}_ssh_user"; ssh_user=${!ssh_user}
		ssh_key="${site}_ssh_key"; ssh_key=${!ssh_key}
		remote_dir="${site}_remote_dir"; remote_dir=${!remote_dir}
		protocol="${site}_protocol"; protocol=${!protocol};
		url="${site}_url"; url=${!url};

		mysql_user="${site}_mysql_user"; mysql_user=${!mysql_user}
		mysql_db="${site}_mysql_db"; mysql_db=${!mysql_db}
		mysql_pwd="${site}_mysql_pwd"; mysql_pwd=${!mysql_pwd}
		mysql_host="${site}_mysql_host"; mysql_host=${!mysql_host}
		mysql_port="${site}_mysql_port"; mysql_port=${!mysql_port}
	fi
}
bucketConfig(){	
	if [ $bucket_provider ]; then
		if [ -z $bucket_name ]; then
			bucket_name=$NAME
		fi

		if [[ $bucket_provider == "gsutil" ]]; then
			bucket_prefix="gs"
			bucket_cmd="gsutil"
			bucket_cp_cmd="cp"
		elif [[ $bucket_provider == "aws" ]]; then
			bucket_prefix="s3"
			bucket_cmd="aws s3"
			bucket_cp_cmd="cp"
		elif [[ $bucket_provider == "s3cmd" ]]; then
			bucket_prefix="s3"
			bucket_cmd="s3cmd"
			bucket_cp_cmd="put"
		fi	
	else
		output -e "No bucket provider given."
		read -p "Do you want to set your bucket now ? [y/n] " answer
		if [ $answer ] && [ $answer == "y" ]; then configureBucket
		else exit; fi
	fi
}

is_ssh(){
	if [ -z $protocol ]; then return 0
	else return 1; fi
}
use_ssh(){
	ssh $ssh_user@$ssh_hostname -i $ssh_key $@
}
use_scp(){
	scp -r -i $ssh_key $ssh_user@$ssh_hostname:$remote_dir $1
}
use_sftp(){
	sftp -r -q -i $ssh_key $ssh_user@$ssh_hostname:$remote_dir $1
}
use_sftp_command(){
	sftp -r -q -i $ssh_key $ssh_user@$ssh_hostname:$remote_dir/$@
}
make_zip(){
	tar -cvzf $@
}
create_temp_folder(){
	backup_name="${site}.$(date +%F_%T | tr ':' '-')"
	tmp_folder="$(mktemp -d -t ${backup_name})"
	tmp_backup="${backup_name}.tar.gz"
	cd $tmp_folder
}

backup_folder(){
	tmp_site_folder=$backup_name

	if is_ssh; then
		use_scp $tmp_site_folder
	else
		use_sftp $tmp_site_folder
	fi
}
test_disk(){
	if is_ssh; then
		use_ssh du -h --max-depth=0 $remote_dir
	else
		output -n -s bold "$(use_sftp_command <<< "pwd")"
	fi
}

backup_mysql(){
	if [ $mysql_host ];
	then 
		mysql_init

		if is_ssh; then
			mysql_dump | gzip > $tmp_folder/$tmp_sql
		else
			php_mysqldump="mysqldump.php"
			sql_dump="database.sql"
			
			put_php_mysqldump

			curl -sL -o /dev/null "$url/$php_mysqldump?dump"
			while [[ $(curl -sLI -o /dev/null -w %{http_code} "$url/$sql_dump") != "200" ]]; do
				printf '.'; sleep 2
			done
			use_sftp_command $sql_dump $tmp_folder

			# remove remote files to avoid leaking datas
			use_sftp_command <<< "rm $sql_dump"
			use_sftp_command <<< "rm $php_mysqldump"

			rm $php_mysqldump && gzip -c $sql_dump > $tmp_sql && rm $sql_dump
		fi
	else
		output -n -s bold "No Sql datas specified for this entity."
	fi
}
mysql_init(){
	tmp_sql="${backup_name}.sql.gz"

	if [ $url ]; then url="http://${url}"
	else url="http://${ssh_hostname#[[:alpha:]]*.}"; fi
	if [ $mysql_host ]; then host=$mysql_host
	else host="localhost"; fi
	if [ $mysql_port ]; then port=$mysql_port
	else port="3306"; fi
}
mysql_dump(){
	use_ssh mysqldump -u $mysql_user -h $host -p$mysql_pwd -P $port $mysql_db --no-tablespaces
}
put_php_mysqldump(){
	cat << EOF > "$php_mysqldump"
<?php
if(isset(\$_GET['dump']))
	system("mysqldump -u $mysql_user -h $host -p$mysql_pwd -P $port $mysql_db > $sql_dump");
?>
EOF
	use_sftp <<< "put $php_mysqldump"
}
test_database(){
	mysql_init

	if is_ssh; then
		use_ssh mysqladmin -u $mysql_user -h $host -p$mysql_pwd -P $port status
	else
		if [ $mysql_db ]; then
			php_mysqltest="mysqltest.php"
			sql_test="mysqltest.txt"

			create_temp_folder

			put_php_mysqltest

			curl -sL -o /dev/null "$url/$php_mysqltest?test"

			while [[ $(curl -sL -o /dev/null -w %{http_code} "$url/$sql_test") != "200" ]]; do
				printf '.'; sleep 2
			done

			use_sftp_command $sql_test $tmp_folder

			output -n -s bold "$(cat $tmp_folder/$sql_test)"

			use_sftp_command <<< "rm $sql_test"
			use_sftp_command <<< "rm $php_mysqltest"

			rm $php_mysqltest && rm $sql_test
		else
			output -n -s bold "No Sql datas specified for this entity."
		fi
	fi
}
put_php_mysqltest(){
	cat << EOF > "$php_mysqltest"
<?php
if(isset(\$_GET['test']))
	system("mysqladmin -u $mysql_user -h $host -p$mysql_pwd -P $port status > $sql_test");
?>
EOF
	use_sftp <<< "put $php_mysqltest"
}

bucket_ls(){
	$bucket_cmd ls -lh $bucket_prefix://$bucket_name/$1
}
bucket_cp(){
	$bucket_cmd $bucket_cp_cmd $1 $bucket_prefix://$bucket_name/$2
}
createKey(){
	if [ $(git config user.email) ]; then
		git_email=$(git config user.email)
	else read -p "Set your email or user@host here, or leave empty: " git_email
	fi

	if [ $git_email ]; then
		git_email="-C $git_email"
	fi

	read -p "Set your passphrase here, or leave empty: " passphrase

	if [ -z $2 ]; then
		read -p "Enter file name in which to save the SSH key in $HOME/.ssh/: " ssh_key_name		
		ssh_key_path=$HOME/.ssh/$ssh_key_name
	else
		ssh_key_path=$2
	fi

	ssh_key_path="${ssh_key_path/#\~/$HOME}"
	
	if [ $ssh_key_path ]
	then
		ssh-keygen -b 2048 -t rsa -f "$ssh_key_path" -N "$passphrase" $git_email

		if [[ $? -eq 0 ]]; then
			output -n "Key generated at $ssh_key_path."
			read -p "Do you want to install that key on remote ? [y/n] " copy
		else exit 1; fi

		if [ $copy ] && [ $copy == "y" ]; then
			output -n "Copying key to remote..."

			if [ $1 ]; then ssh_remote=$1; fi
			copyKey "$ssh_remote" $ssh_key_path
		fi
	else
		output -n -e "No key path specified."
	fi
}
copyKey(){
	if [ $1 ]; then ssh_remote=$1
	else read -p "Enter the username@hostanme, for which you want to authorized the key: " ssh_remote; fi

	if [ $2 ]; then ssh_key_path="${2//\~/$HOME}"
	else read -p "Enter full path name of the SSH key: " ssh_key_path; fi

	if [ $ssh_key_path ] && [ $ssh_remote ]
	then
		ssh-copy-id -i $ssh_key_path $ssh_remote

		if [[ $? -eq 0 ]]; then
			output -n "🍺 The key has been authorized on remote."
		else exit 1; fi
	else 
		output -n -e "No key or remote provided."
	fi
}

link(){
	if [ ! -f "$command_path$1" ];
	then
		ln -s "$source_file" $command_path$1
		output -n -s bold "Command linked !"
	else
		output -n "Command already linked."
	fi
}
unlink(){
	if [ -f "$command_path$1" ];
	then 
		rm $command_path$1
		output -n -s bold "Command unlinked."
	elif [ -f "$command_path$NAME" ];
	then 
		rm $command_path$NAME
		output -n -s bold "Command unlinked."
	else
		output -n "No command to be removed."
	fi
}

case $1 in
	backup)
		if [ "$2" == "disk" ] || [ "$2" == "mysql" ]
			then envSetup $3; else envSetup $2; fi

		create_temp_folder

		case $2 in
			disk) backup_folder ;;
			mysql) backup_mysql ;;
			*) backup_folder && backup_mysql;;
		esac

		if [ -d $tmp_site_folder ] || [ -f $tmp_sql ];
		then
			make_zip $tmp_backup $tmp_site_folder $tmp_sql

			rm -r $tmp_site_folder $tmp_sql

			bucket_cp $tmp_backup ${site}/

			echo $backup_name: $tmp_folder >> $log_file
		fi
	;;

	connect) envSetup $2;  if is_ssh; then use_ssh -t "cd $remote_dir; bash --login"; fi ;;
	run) envSetup $2; shift 2; if is_ssh; then use_ssh "cd $remote_dir && $@"; fi ;;
	ls|list)
		if [ $2 ]; then envSetup $2;
			output -s bold "$site :"; output -s bold "$ssh_hostname $remote_dir";
			[[ $url ]] && output -s bold $url; output -n;
		else checkConfig; printf '%s\n' "${sites[@]}" | sort; fi
	;;
	bucket) checkConfig; bucket_ls $2 ;;
	test)
		case $2 in
			disk) envSetup $3; test_disk ;;
			mysql) envSetup $3; test_database ;;
			*) envSetup $2; test_disk && test_database
		esac
	;;
	key)
		if [ $3 ] && [ $4 ]; then
			key="$3"
			remote="$4"
		elif [ $3 ]; then
			envSetup $3
			remote="$ssh_user@$ssh_hostname"
			key="$ssh_key"
		fi

		case $2 in
			create) createKey $remote $key ;;
			copy) copyKey $remote $key ;;
		esac
	;;
	link) link $2 ;;
	unlink)	unlink $2 ;;
	configure) checkConfig; newWebsite ;;
	log) cat $log_file ;;
	help|*) usage ;;
esac
