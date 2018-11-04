#!/bin/bash
#
# @Weedo.Agency toolkit
# Jeromin <me@jeromin.fr>

NAME=$(basename "${BASH_SOURCE[0]}")
source_file="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$NAME"
vars_file="$HOME/.$NAME"
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
	local 
	output -c magenta -n "$(echo $NAME | awk '{print toupper(substr($0,0,1)) tolower(substr($0,2,length($0)))}') backup toolkit."; output -n
    output -c magenta -s bold -n "Usage:"
    output -n "./$NAME ls [site]"
    output -n "./$NAME backup [disk|mysql] site"
    output -n "./$NAME connect site"
    output -n "./$NAME run site command"
    output -n "./$NAME bucket [site]"
    output -n "./$NAME key create|copy [site]"
    output -n "./$NAME test [disk|mysql] site"
    output -n "./$NAME link|unlink [name]"
    output -n "./$NAME configure|help"
    exit 0
}
finish(){
	if [ $? = 1 ]; then
		output -n "☠️ \x20 The script did not terminated well."
	fi
}
trap finish QUIT EXIT

newWebsite(){
	read -p "Name (ID) of the website : " name

	if [ ! -z $name ]; then
		read -p "SSH hostname : " ssh_hostname; fi
	if [ ! -z $ssh_hostname ]; then 
		read -p "SSH user : " ssh_user; fi
	if [ ! -z $ssh_user ]; then
		read -p "Do you need to create an SSH key ? [y/n] ? " create
		if [ ! -z $create ] && [ $create == "y" ]; then
			createKey $ssh_user@$ssh_hostname
			ssh_key=$ssh_key_path
		else
			read -p "SSH key path : " ssh_key
		fi
	fi
	if [ ! -z $ssh_key ]; then 
		read -p "Remote folder path : " remote_dir; fi
	if [ ! -z $remote_dir ]; then
		read -p "Which transfer protocol will you use [ssh|scp] ? " protocol
	fi
	if [ $protocol == "ssh" ]; then
		read -p "MySql user : " mysql_user
		read -p "MySql database : " mysql_db
		read -p "MySql password : " mysql_pwd
	fi

	if [ ! -z $name ] && [ ! -z $ssh_hostname ] && [ ! -z $ssh_user ] && [ ! -z $ssh_key ] && [ ! -z $remote_dir ]; then
		echo ${name}_ssh_hostname=$ssh_hostname >> $vars_file
		echo ${name}_ssh_user=$ssh_user >> $vars_file
		echo ${name}_ssh_key=$ssh_key >> $vars_file
		echo ${name}_remote_dir=$remote_dir >> $vars_file
		if [[ $protocol == "scp" ]]; then
			echo ${name}_protocol=$protocol >> $vars_file; fi

		if [ ! -z $mysql_user ] && [ ! -z $mysql_db ] && [ ! -z $mysql_pwd ]; then
			echo ${name}_mysql_user=$mysql_user >> $vars_file
			echo ${name}_mysql_db=$mysql_db >> $vars_file
			echo ${name}_mysql_pwd=$mysql_pwd >> $vars_file
		fi

		echo "\n" >> $vars_file
	fi
}
configureBucket(){
	read -p "Which provider do you want to use as Bucket ? [gsutil/aws/s3cmd] " provider
	if [ ! -z $provider ]; then
		echo "bucket_provider=$provider" >> $vars_file
		read -p "Type your bucket name, or leave empty to use script name [$NAME] " bucket_name		
		
		if [ ! -z $bucket_name ]; then echo "bucket_name=$bucket_name" >> $vars_file; fi

		echo >> "$vars_file"

	else exit 0; fi
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
	# If vars file is present then load variables from it
	if [ -f "$vars_file" ]; then
		for line in $(awk -F= '{print $1}' "$vars_file"); do
			readonly "${line}"=$(awk -F= '$1=="'$line'"{print $2}' "$vars_file")
			IFS='_' read -r -a array <<< "${line}"
			if [[ ${array[2]} == "hostname" ]]; then sites+=(${array[0]}); fi
		done

		bucketConfig

		if [ ${#sites[@]} -eq 0 ]; then
			output -n "No website configuration found."
			read -p "Do you want to set up now ? [y/n] " answer
			if [ ! -z $answer ] && [ $answer == "y" ]; then newWebsite
			else exit 0; fi
		fi

	else
		output -n "No configuration file found."
		read -p "Do you want to set ip up now ? [y/n] " answer
		if [ ! -z $answer ] && [ $answer == "y" ]; then setup
		else exit 0; fi
	fi
}
envSetup(){
	checkConfig

	if [ -z $1 ]; then
		output -n -e "Site name is expected."; usage; exit 0
	else 
		site=$1;

		ssh_hostname="${site}_ssh_hostname"; ssh_hostname=${!ssh_hostname}

		if [ -z $ssh_hostname ]; then
			output -n -e "Site name is not correct."; usage; exit 0; fi

		ssh_user="${site}_ssh_user"; ssh_user=${!ssh_user}
		ssh_key="${site}_ssh_key"; ssh_key=${!ssh_key}
		remote_dir="${site}_remote_dir"; remote_dir=${!remote_dir}
		protocol="${site}_protocol"; protocol=${!protocol};

		mysql_user="${site}_mysql_user"; mysql_user=${!mysql_user}
		mysql_db="${site}_mysql_db"; mysql_db=${!mysql_db}
		mysql_pwd="${site}_mysql_pwd"; mysql_pwd=${!mysql_pwd}
		mysql_host="${site}_mysql_host"; mysql_host=${!mysql_host}
	fi
}
bucketConfig(){	
	if [ ! -z $bucket_provider ]; then
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
		if [ ! -z $answer ] && [ $answer == "y" ]; then configureBucket
		else exit 0; fi
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
	sftp -r -i $ssh_key $ssh_user@$ssh_hostname:$remote_dir $1
}
backup_folder(){
	tmp_site_folder="$tmp_folder/site"

	if is_ssh; then
		use_scp $tmp_site_folder
	else
		use_sftp $tmp_site_folder
	fi

	tmp_backup="site.tar.gz"

	make_zip $tmp_folder/$tmp_backup -C $tmp_site_folder .
}
backup_mysql(){	
	if is_ssh; then
		tmp_sql="database.sql"
		mysql_dump  > $tmp_folder/$tmp_sql
	fi
}
make_zip(){
	tar -cvzPf $@
}
mysql_dump(){
	if [ ! -z $mysql_host ]; then host=$mysql_host
	else host="localhost"; fi

	ssh $ssh_user@$ssh_hostname -i $ssh_key \
		"mysqldump -u $mysql_user -h $host -p$mysql_pwd $mysql_db"
}
bucket_ls(){
	$bucket_cmd ls $bucket_prefix://$bucket_name/$1
}
bucket_cp(){
	$bucket_cmd $bucket_cp_cmd $1 $bucket_prefix://$bucket_name/$2
}
test_disk(){
	if is_ssh; then
		use_ssh du -h --max-depth=0 $remote_dir
	else output -n "This site is using scp, test manually using sftp."
	fi
}
test_database(){
	if is_ssh; then
		if [ ! -z $mysql_host ]; then host=$mysql_host
		else host="localhost"; fi

		use_ssh mysqladmin -u $mysql_user -h $host -p$mysql_pwd status
	fi
}
createKey(){
	if [ -z $1 ]; then		
		read -p "Enter the username@hostanme, for which you want to authorized the key: " ssh_remote
	else ssh_remote=$1; fi

	if [ ! -z $(git config user.email) ]; then
		git_email="-C $(git config user.email)"; fi

	read -p "Set your passphrase here, or leave empty: " passphrase

	if [ -z $2 ]; then
		read -p "Enter file name in which to save the SSH key in $HOME/.ssh/: " ssh_key_name		
		ssh_key_path=$HOME/.ssh/$ssh_key_name
	else
		ssh_key_path=$2
	fi
	
	if [ ! -z $ssh_key_path ] && [ ! -z $ssh_remote ]
	then
		ssh-keygen -b 2048 -t rsa -f $ssh_key_path -q -N "$passphrase" $git_email

		if [[ $? -eq 0 ]]; then
			output -n "Key generated at $ssh_key_path. Copying to remote..."
		else exit 1; fi

		copyKey $ssh_remote $ssh_key_path
	else
		output -n -e "No name or remote provided."
	fi
}
copyKey(){
	if [ ! -z $2 ] && [ ! -z $1 ]; then
		ssh_key_path="${2//\~/$HOME}"
		ssh_remote=$1
	else	
		read -p "Enter the username@hostanme, for which you want to authorized the key: " ssh_remote
		read -p "Enter full path name of the SSH key: " ssh_key_path
	fi

	if [ ! -z $ssh_key_path ] && [ ! -z $ssh_remote ]
	then
		ssh-copy-id -i $ssh_key_path $ssh_remote

		if [[ $? -eq 0 ]]; then
			output -n "🍺 The key has been authorized on remote."
		else exit 1; fi
	else 
		output -n -e "No name or remote provided."
	fi
}

case $1 in
	backup)
		if [ $2 == "disk" ] || [ $2 == "mysql" ]; then
			envSetup $3
		else envSetup $2; fi

		backup_name="${site}.$(date +%F_%T | tr ':' '-')"

		if [ -d $TMDIR ]; then
			tmp_folder="$(mktemp -d "$TMPDIR"${backup_name}.XXXXXX)"
		else tmp_folder="$(mktemp -d /tmp/${backup_name}.XXXXXX)"
		fi

		cd $tmp_folder

		case $2 in
			disk) backup_folder;;
			mysql) backup_mysql;;
			*) backup_folder && backup_mysql;;
		esac

		make_zip $tmp_folder/all.tar.gz $tmp_backup $tmp_sql

		echo $backup_name: $tmp_folder >> $log_file

		bucket_cp $tmp_folder/all.tar.gz ${site}/${backup_name}.tar.gz
	;;

	connect) envSetup $2;  if is_ssh; then use_ssh; fi	;;
	run) envSetup $2; shift 2; if is_ssh; then use_ssh $@; fi	;;
	ls) if [ ! -z $2 ]; then envSetup $2;
			output -s bold "$site :"; output -n "$ssh_hostname $remote_dir"
		else checkConfig; printf '%s\n' "${sites[@]}"; fi
	;;
	bucket) checkConfig; bucket_ls $2 ;;
	test)
		case $2 in
			disk) envSetup $3; test_disk ;;
			mysql) envSetup $3; test_database ;;
			*) envSetup $2; test_disk && test_database
		esac
	;;

	configure) checkConfig; newWebsite ;;
	key)
		 if [ ! -z $3 ]; then envSetup $3;
			key_options="$ssh_user@$ssh_hostname $ssh_key"; fi

		case $2 in
			create) createKey $key_options;;
			copy) copyKey $key_options;;
		esac
	;;
	link) link $2 ;;
	unlink)	unlink $2;;
	help|*) usage ;;
esac

