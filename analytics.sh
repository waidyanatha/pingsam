# -------------------------------------------------------------------
# ANALYZE LOG FILES FOR PATTERNS
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
LOG_DNAME="oldlogs"
OUT_FNAME="weeklylogs.csv"
############# MAIN PROCEDURE ##############
#
#check if logs archive folder exisits
if [ ! -d "$LOG_DNAME" ]; then
	echo "process stopping cannot locate $LOG_DNAME"
	exit
fi
if [ -f "$OUT_FNAME" ]; then
	rm $OUT_FNAME
fi
#check if folder contains N > 0 number of files, true - bzip them in a folder
count=`ls -1 $LOG_DNAME/*.log 2>/dev/null | wc -l`
if [ $count != 0 ]; then  
    shopt -s nullglob
    array=($LOG_DNAME/*.log)
    SEQNUM=0
    for FILE in "${array[@]}"
    do    
        while IFS= read -r ROW
        do
            #NOW = grep now and replicate row
            DATETIME=`echo $ROW | cut -d' ' -f 1`
            IP=`echo $ROW | cut -d' ' -f 4`
            BEFORE=`echo $ROW | cut -d' ' -f 5`
            NOW=`echo $ROW | cut -d' ' -f 6`
            if [ $NOW = "now:UP" ]; then
                NOW=1
                BEFORE=0
            else
                NOW=0
                BEFORE=1
            fi
            SEQNUM=$(( SEQNUM+1 ))
            echo "$SEQNUM,$DATETIME,$IP,$BEFORE" >> $OUT_FNAME
#            SEQNUM=$(( SEQNUM+1 ))
#            echo "$SEQNUM,$DATETIME,$IP,$NOW" >> $OUT_FNAME
            #echo $ROW >> $OUT_FNAME
        done < <(grep "STATE:" $FILE)
    done        
else
    echo "no log files in $LOG_DNAME"
fi

