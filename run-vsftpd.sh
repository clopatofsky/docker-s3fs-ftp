#!/bin/bash

# If no env var for FTP_USER has been specified, use 'admin':
if [ "$FTP_USER" = "**String**" ]; then
    export FTP_USER='admin'
fi

# If no env var has been specified, generate a random password for FTP_USER:
if [ "$FTP_PASS" = "**Random**" ]; then
    export FTP_PASS=`cat /dev/urandom | tr -dc A-Z-a-z-0-9 | head -c${1:-16}`
fi

# Do not log to STDOUT by default:
if [ "$LOG_STDOUT" = "**Boolean**" ]; then
    export LOG_STDOUT=''
else
    export LOG_STDOUT='Yes.'
fi

# If no env var has been specified, generate a random password for S3_BUCKET:
if [ "$S3_BUCKET" = "**String**" ]; then
    export S3_BUCKET='ftp-bucket-fuse'
fi

# If no env var has been specified, generate a random password for IAM_ROLE:
if [ "$IAM_ROLE" = "**String**" ]; then
    export IAM_ROLE='S3FS-Role'
fi

# If no env var has been specified, generate a random password for S3_ENDPOINT:
if [ "$S3_ENDPOINT" = "**String**" ]; then
    export S3_ENDPOINT='https://s3.us-east-1.amazonaws.com'
fi

# Create home dir and update vsftpd user db:
mkdir -p "/home/vsftpd/${FTP_USER}"
chown -R ftp:ftp /home/vsftpd/

echo -e "${FTP_USER}\n${FTP_PASS}" > /etc/vsftpd/virtual_users.txt
/usr/bin/db_load -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db

# Set passive mode parameters:
if [ "$PASV_ADDRESS" = "**IPv4**" ]; then
    export PASV_ADDRESS=$(/sbin/ip route|awk '/default/ { print $3 }')
fi

echo "pasv_address=${PASV_ADDRESS}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_max_port=${PASV_MAX_PORT}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_min_port=${PASV_MIN_PORT}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_addr_resolve=${PASV_ADDR_RESOLVE}" >> /etc/vsftpd/vsftpd.conf
echo "pasv_enable=${PASV_ENABLE}" >> /etc/vsftpd/vsftpd.conf
echo "file_open_mode=${FILE_OPEN_MODE}" >> /etc/vsftpd/vsftpd.conf
echo "local_umask=${LOCAL_UMASK}" >> /etc/vsftpd/vsftpd.conf

# Get log file path
export LOG_FILE=`grep xferlog_file /etc/vsftpd/vsftpd.conf|cut -d= -f2`

# stdout server info:
if [ ! $LOG_STDOUT ]; then
cat << EOB
	********************************************************
	*                                                      *
	*    Docker image: clopatofsky/docker-s3fs-ftp         *
	*    https://github.com/clopatofsky/docker-s3fs-ftp    *
	*                                                      *
	********************************************************

	SERVER SETTINGS
	---------------
	· FTP User: $FTP_USER
	· FTP Password: $FTP_PASS
	· Log file: $LOG_FILE
	· IAM Role: $IAM_ROLE
	· S3 bucket: $S3_BUCKET
	· S3 endpoint: $S3_ENDPOINT
	· Redirect vsftpd log to STDOUT: No.
EOB
else
    /usr/bin/ln -sf /dev/stdout $LOG_FILE
fi

# Run s3fs:
/usr/local/bin/s3fs ${S3_BUCKET} -o use_cache=/tmp,iam_role=${IAM_ROLE},allow_other /home/vsftpd/${FTP_USER} -o url=${S3_ENDPOINT}

# Run vsftpd:
&>/dev/null /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf

