#!/bin/sh

#
# Backup script by timdream
#

# variables to construct rsync command
SSHKEY=/home/demo/backup/id_rsa
RINFO=$1 # e.g. "backup@remote.server"
RPATH=$2 # e.g. "/media/web_vhosts", WITHOUT TRAILING SLASH
LPATH=$3
LOG=$3

# number of backup copies to keep
COPIES=3

# mysqldump and user on remote side
MYSQLDUMP='/usr/bin/mysqldump'
MYSQLUSER='backup'


# === that's all!

# backup remote site test (--dry-run)
echo 'rsync dry run ...'
date > $LOG.dry-run.log
echo >> $LOG.dry-run.log
rsync -e "ssh -i $SSHKEY" -avvzP --delete --dry-run $RINFO:$RPATH/ $LPATH/ >> $LOG.dry-run.log 2>&1

if [ $? -eq 1 ]; then
        #dry run failed. stop the back up and insert warning
        exit 1;
fi

# rsync backup in directory N to N+1
for NUM in `seq $COPIES -1 1`
do
	PREV=`expr $NUM - 1`
	if [ -d $LPATH.$PREV ]; then
		echo 'rsync '$NUM' ...'
		date > $LOG.$NUM.log
		echo >> $LOG.$NUM.log
		rsync -avvP --delete $LPATH.$PREV/ $LPATH.$NUM/ >> $LOG.$NUM.log 2>&1
	fi
done

# rsync dictionary to dictionary 0
if [ -d $LPATH ]; then
        echo 'rsync 0 ...'
        date > $LOG.0.log
        echo >> $LOG.0.log
        rsync -avvP --delete $LPATH/ $LPATH.0/ >> $LOG.0.log 2>&1
fi

mkdir -p $LPATH;

echo 'rsync with remove host ...'
date > $LOG.log
echo >> $LOG.log
rsync -e "ssh -i $SSHKEY" -avvzP --delete $RINFO:$RPATH/ $LPATH/ >> $LOG.log 2>&1
date > $LPATH/backup-time.txt
for DBDIR in `ls $LPATH/*/dbname.txt | awk '{print substr($1, 1, length($1)-11)}'`
do
	for DBNAME in `cat $DBDIR/dbname.txt`
	do
		echo 'dumping database '$DBNAME' in '$DBDIR' ...';
		ssh -i $SSHKEY $RINFO "$MYSQLDUMP -u $MYSQLUSER $DBNAME | gzip" > $DBDIR/latest-$DBNAME.tar.gz 2>/dev/null
	done
done
echo 'done.'
rm $LOG.dry-run.log

