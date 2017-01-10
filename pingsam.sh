# -------------------------------------------------------------------
# TO PING SERVERS IN THE RESPECTIVE COUNTRIES AND NOTIFY STATE CHANGE
# -------------------------------------------------------------------
#
#   nuwan at sahanafoundation dot org
#
#   NOTE:   to execute preiodically add a cron job by using <crontab -e>
#   example - cd ~/pingsam/ bash ./pingsam.sh
#
#!/bin/sh
#
################### STATIC VARIABLES ################################
#
IPLIST_FNAME="master.csv"	# IPs and relatred information file
STATE_FNAME="state.csv"	    # generated for processing and updating IP ping results
LOG_FNAME="./pingsam.log"   # to log the outcomes of each process and function
MAX_PING_COUNT=3            #set the number of iterations to test if ping fails before determining its down
#
################## FUNCTION: LOG () #################################
#
# function takes a prefix and string to write the string to the log-file
# prefixes are: PROCESS, ERROR, WARNING, SUCCESS, STATE
# format of the log string = datetime prefix: string
#
function log ()
{
	#check if the logfile exists, if not create new
	if [ ! -f $LOG_FNAME ]; then
		echo >> $LOG_FNAME
		chmod u=rw,g=rw,o=r $LOG_FNAME
	fi
	#if only one arg, then likely that prefix is null and only a string is supplied 
	if [ -z "$2" ] && [ ! -z "$1" ]; then
		MSG=$1
		PREFIX="UNKNOWN"
	else
		MSG=$2
		PREFIX="$1"
	fi	
	DATETIME=$(date +"%Y-%m-%d:%H:%M:%S")
	LOG_STR="$DATETIME $PREFIX: $MSG"
	echo $LOG_STR >> $LOG_FNAME
	return 0
}
#
################## FUNCTION: UPDATE_STATE_FILE () ##########################
#
#check if all the unique IPs are in the IP-STATE file; if not update it
#   arg $1 = main_file (IPLIST_FNAME)
#   arg $2 = auxiliary file (STATE_FNAME)
#   arg $3 = log file (LOG_FNAME)
#
function update_state_file ()
{
	#Read the instance data from ipfile.csv to make sure status file is upto date
	IP_ARRAY=() # Create array
	x=0
	{
    	read
    	while IFS="," read -r SN IP COUNTRY INSTANCE NAME EMAIL PHONE
    	do
        	IP_ARRAY+=($IP)
    	done 
	} < $1
	#
	#check if array is null and there are indeed IPs
	if [ ${#IP_ARRAY[@]} -eq 0 ]; then
		local retnval=-1
	else
		#Get the unique IPs
		UNIQUE_IPS=($(echo "${IP_ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
		local retnval=0
	fi
	#
	#update list with any new IPs inserted
	for UIP in "${UNIQUE_IPS[@]}"
	do
		TMP_IP=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 1` #check if IP already exists
		if [ -z "$TMP_IP" ]; then
			echo "$UIP,UP,UP,0" >> $2
#			log "SUCCESS" "Added the $UIP to $2"
		else
			#reset the ping iteration count to 0
			OLD_STR="$UIP,"
			OLD_STR+=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 2`
			OLD_STR+=","
			OLD_STR+=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 3`
			OLD_STR+=","
			NEW_STR=$OLD_STR
			OLD_STR+=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 4`
			NEW_STR+="0"
			sed -i "s/$OLD_STR/$NEW_STR/g" $2
		fi
	done
	#
	return $retnval
}
################## FUNCTION: ALERT_STATUS () ##########################
#
# function matches the current state with the previous state to determine
# the next action of whether or not to alert the new change in the status
#   arg $1=NEW_STATE      - detected new state of the ping
#   arg $2=OLD_STATE      - ping state during last iteration
#   arg $3=IPLIST_FNAME   - master file with ip info and contact details
#   arg $4=UIP            - IP address (or URL) being processed
#
function alert_status ()
{
	if [ "$1" != "$2" ]; then
		{
    		read
    		while IFS="," read -r SN IP COUNTRY INSTANCE NAME EMAIL PHONE
    		do
			if [ "$IP" = "$4" ]; then
                    		local CHECKDT=$(date +"%Y-%m-%d:%H:%M:%S")
				mail -s "[PINGSAM] $COUNTRY $INSTANCE server $1" "$EMAIL" <<< "$NAME - Server: $4 was $2 and now it is $1; ping date and time: $CHECKDT (UTC)"
			fi
    		done 
		} < $3
        local retnval=1
    else
        local retnval=0
	fi
	return $retnval
}
############  [A] CHECK NECESSARY AND SUFFICIENT FILES ################
#
log "PROCESS" "----------------------------------------------"
log "PROCESS" "Starting monitoring service with PID=$$"
#
#Check if the ip info file exists
log "PROCESS" "checking dependant files ..."
if [ ! -f "$IPLIST_FNAME" ]; then
    log "ERROR" "File not found $IPLIST_FNAME."
	log "INSTRUCTION" "Copy the $IPLIST_FNAME to the same directory and run script again."
	log "PROCESS" "Stopping"
	echo "process stopping, check the $LOG_FNAME for ERRORs"
	exit
else
	log "SUCCESS" "$IPLIST_FNAME exists ... we are moving on."
fi
#
#check if the ping status file exists, if not create new
#
	if [ ! -f $STATE_FNAME ]; then
#if [ ! -f $2 ]; then
    log "WARNING" "$STATE_FNAME File not found!"
    log "PROCESS" "Creating $STATE_FNAME in file directory."
	echo >> $STATE_FNAME
	chmod u=rw,g=rw,o=r $STATE_FNAME
	awk '{if (NR==1 && NF==0) next};1' < ${STATE_FNAME} > ${STATE_FNAME}.killfirstline
   	mv ${STATE_FNAME}.killfirstline ${STATE_FNAME}
fi
#
#######################  [B] MAIN PROCEDURE - WE ARE READY TO PING #######################
#
update_state_file $IPLIST_FNAME $STATE_FNAME	#make sure the list of IPs to process are upto date
if [ $? -ne 0 ]; then    	
	log "ERROR" "No records in $IPLIST_FNAME!"
	log "INSTRUCTION" "Add records in $IPLIST_FNAME to start monitoring them."
	log "PROCESS" "Stopping."
	echo "process stopping, check the $LOG_FNAME for ERRORs"
	exit
else
	log "SUCCESS" "Found ${#UNIQUE_IPS[@]} IP Addresses to monitor."
fi
#
log "PROCESS" "Starting to monitor the servers"
for UIP in "${UNIQUE_IPS[@]}"		
do
    INTERNET_STATE="DOWN"	# default my internet to be down
	OLD_STATE=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 2`	#set old-state with previou new-state value
    PING_COUNT=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 4`
    TEST=`ping -c$MAX_PING_COUNT ${UIP} | grep "$MAX_PING_COUNT packets transmitted" `
    TEST_SEND=`echo $TEST | grep "$MAX_PING_COUNT packets transmitted" | cut --delimiter="," -f 1`
    TEST_RECV=`echo $TEST | grep "$MAX_PING_COUNT packets transmitted" | cut --delimiter="," -f 2`
    if [[ "$TEST_SEND" = "$MAX_PING_COUNT packets transmitted" ]]; then   # test connected to the internet
        INTERNET_STATE="UP"
        if [[ "$TEST_RECV" = " 0 received" ]]; then
            NEW_STATE="DOWN"
        else
            NEW_STATE="UP"	#all good				
        fi  #test received done
		#compare previous and current states; if a mismatch then email and update with matching states
		alert_status $NEW_STATE $OLD_STATE $IPLIST_FNAME $UIP
		case $? in
            0) #log "STATE" "Unchanged $UIP before:$OLD_STATE now:$NEW_STATE"
                ;;
            1) log "STATE" "Changed $UIP before:$OLD_STATE now:$NEW_STATE"
                ;;
            *)
				log "ERROR" "function match_states with args IP=$UIP, OLD_STATE=$OLD_STATE, and NEW_STATE=$NEW_STATE failed!"
				log "PROCESS" "Stopping"
				echo "process stopping, check the $LOG_FNAME for ERRORs"
				exit
                ;;
			esac
        #update the states and iterations         
		OLD_STR="$UIP,"
		NEW_STR="$UIP,"
		OLD_STR+=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 2`
		OLD_STR+=","
		NEW_STR+="$NEW_STATE,"
		OLD_STR+=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 3`
		NEW_STR+=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 3`
		OLD_STR+=","
		NEW_STR+=","
		OLD_STR+=`grep "$UIP" < $STATE_FNAME | cut --delimiter="," -f 4`
		NEW_STR+="$PING_COUNT"
		sed -i "s/$OLD_STR/$NEW_STR/g" $STATE_FNAME
    else
        INTERNET_STATE="DOWN"
		log "WARNING" "Internet is $INTERNET_STATE; will try again in 60 seconds"
        sleep 60 ; # sleep: 60 seconds = 1 min for the internet to reconnect
    fi  # test internet connection done
done
log "PROCESS" "Finishing monitoring service with PID=$$"
#Exit
