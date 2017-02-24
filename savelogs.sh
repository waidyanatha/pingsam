# -------------------------------------------------------------------
# ARCHIVE LOG FILES
# -------------------------------------------------------------------
#
#   nuwan at sahanafoundation dot org
#
#   NOTE:   to execute preiodically add a cron job by using <crontab -e>
#   example - bash /home/nuwan/workspace/pingsam/pingsam.sh
#
#!/bin/sh
#
# Process will archive pingsam.log file in the "oldlogs' folder each day just
# just before midnight; i.e. 1 file each day. Oldest 7 files will be bzip-ed
# and emailed to administrator
#
############# STATIC VARS #################
ADM_EMAIL="men@example.com"
FROM_EMAIL="me@example.com"
LOG_DNAME="oldlogs"
LOG_FNAME="./pingsam.log"   # to log the outcomes of each process and function
MAX_FILES=7
############# MAIN PROCEDURE ##############
#
#check if logs archive folder exisits
if [ ! -d "$LOG_DNAME" ]; then
    mkdir $LOG_DNAME
fi
#check if folder contains N number of files, true - bzip them in a folder
count=`ls -1 $LOG_DNAME/*.log 2>/dev/null | wc -l`
if [ $count != 0 ]; then  
    if [ `ls -1 $LOG_DNAME/*.log | wc -l` -ge "$MAX_FILES" ]; then
        WEEK=$(date +"%V")
        ARC_DNAME="week-$WEEK-logs"
        if [ ! -d "$LOG_DNAME/$ARC_DNAME" ]; then
            mkdir "$LOG_DNAME/$ARC_DNAME"
        fi
        mv $LOG_DNAME/*.log $LOG_DNAME/$ARC_DNAME/
        tar -cjf $LOG_DNAME/$ARC_DNAME.tar.bz2 $LOG_DNAME/$ARC_DNAME/
        rm -rf $LOG_DNAME/$ARC_DNAME
        mail -s "[PINGSAM] $ARC_DNAME" -a "$LOG_DNAME/$ARC_DNAME.tar.bz2" "$ADM_EMAIL" <<< "$ARC_DNAME from pingsam log archives" 
    fi
#else
#    echo "no log files in $LOG_DNAME"
fi
#now move latest logfile to oldlogs folder
if [ ! -f "$LOG_FNAME" ]; then
	echo "process stopping cannot locate $LOG_FNAME"
	exit
else
    DATETIME=$(date +"%Y%m%d")
	mv "$LOG_FNAME" "$LOG_DNAME/pingsam-$DATETIME.log"
fi
