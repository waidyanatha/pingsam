# pingsam
Checks the UP and DOWN status of a remote machine by simply pinging or telnet-ing to the remote URL or IP.

To simply monitor the remote IP-enabled machines, you only need the two files: pingsam.sh and master.csv
To automatically archive the log files, then use savelogs.sh script.
To schedule execution of either one of the scripts you should create a cronjob

## master.csv
* It is important that the file remains a comma delimited separated file and should not use no other delimiter.
* The name of the master.csv file can be changed (e.g. myipfile.csv). If you do so, remember to change the name in pingsam.sh

## pingsam.sh
* the script only requires the master.csv file to start the process; while pingsam.log and status.csv are automatically created by the script. 
