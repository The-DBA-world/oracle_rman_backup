#!/bin/bash
# #####################################################################################################
# #################This script takes an on-demand RMAN Backup.#########################################
### Customized the script to run on various environments.       #######################################
### Run RMAN command in the background to avoid job fail when session terminate.#######################
### Added Backup Encryption Option.                             #######################################
### Added Channels Number feature.                              #######################################
### Added Controlfile compressed backup option.                 #######################################
### Restricting the user from skipping the backup location.     #######################################
### Changing Backup date format to DD-Mon-YY.                   #######################################
### Check the DB Open mode and the ARCHIVELOG mode.             #######################################
### Check if the RECOVERY is running for a STANDBY DB to avoid inconsistency bug.######################
### Include Parallelism option when starting the RECOVER on a STANDBY DB.##############################
# #####################################################################################################

# ###########
# Description:
# ###########
echo
echo "==================================================="
echo "This script Takes a RMAN FULL Backup of a database."
echo "==================================================="
echo
sleep 1

# ###########################
# CPU count check:
# ###########################

# Count of CPUs:
CPU_NUM=`cat /proc/cpuinfo|grep CPU|wc -l`
export CPU_NUM


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM|APX"                           #Excluded INSTANCES [Will not get reported offline].


# ##############################
# SCRIPT ENGINE STARTS FROM HERE ............................................
# ##############################

# ###########################
# Listing Available Databases:
# ###########################

# Count Instance Numbers:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )

# Exit if No DBs are running:
if [ $INS_COUNT -eq 0 ]
 then
   echo "No Database is Running !"
   echo
   return
fi

# If there is ONLY one DB set it as default without prompt for selection:
if [ $INS_COUNT -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# If there is more than one DB ASK the user to select:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo "Select the ORACLE_SID:[Enter the number]"
    echo "---------------------"
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
                integ='^[0-9]+$'
                if ! [[ ${REPLY} =~ ${integ} ]] || [ ${REPLY} -gt ${INS_COUNT} ] || [ ${REPLY} -eq 0 ]
                        then
                        echo
                        echo "Error: Not a valid number!"
                        echo
                        echo "Enter a valid NUMBER from the displayed list !: i.e. Enter a number from [1 to ${INS_COUNT}]"
                        echo "----------------------------------------------"
                else
                        export ORACLE_SID=$DB_ID
                        echo 
                        printf "`echo "Selected Instance: ["` `echo -e "\033[33;5m${DB_ID}\033[0m"` `echo "]"`\n"
                        echo
                        break
                fi
     done

fi
# Exit if the user selected a Non Listed Number:
        if [[ -z "${ORACLE_SID}" ]]
         then
          echo "You've Entered An INVALID ORACLE_SID"
          exit
        fi


# #########################
# Getting ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|grep -v "\-MGMTDB"|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

# SETTING ORATAB:
if [[ -f /etc/oratab ]]
  then
  ORATAB=/etc/oratab
  export ORATAB
## If OS is Solaris:
elif [[ -f /var/opt/oracle/oratab ]]
  then
  ORATAB=/var/opt/oracle/oratab
  export ORATAB
fi

# ATTEMPT1: Get ORACLE_HOME using pwdx command:
export PGREP=`which pgrep`
export PWDX=`which pwdx`
if [[ -x ${PGREP} ]] && [[ -x ${PWDX} ]]
then
PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
export PMON_PID
ORACLE_HOME=`pwdx ${PMON_PID} 2>/dev/null|awk '{print $NF}'|sed -e 's/\/dbs//g'`
export ORACLE_HOME
fi

# ATTEMPT2: If ORACLE_HOME not found get it from oratab file:
if [[ ! -f ${ORACLE_HOME}/bin/sqlplus ]]
 then
## If OS is Linux:
if [[ -f /etc/oratab ]]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## If OS is Solaris:
elif [[ -f /var/opt/oracle/oratab ]]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi
#echo "ORACLE_HOME from oratab is ${ORACLE_HOME}"
fi

# ATTEMPT3: If ORACLE_HOME is still not found, search for the environment variable: [Less accurate]
if [[ ! -f ${ORACLE_HOME}/bin/sqlplus ]]
 then
  ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from environment  is ${ORACLE_HOME}"
fi

# ATTEMPT4: If ORACLE_HOME is not found in the environment search user's profile: [Less accurate]
if [[ ! -f ${ORACLE_HOME}/bin/sqlplus ]]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
#echo "ORACLE_HOME from User Profile is ${ORACLE_HOME}"
fi

# ATTEMPT5: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [[ ! -f ${ORACLE_HOME}/bin/sqlplus ]]
 then
  ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from orapipe search is ${ORACLE_HOME}"
fi

# TERMINATE: If all above attempts failed to get ORACLE_HOME location, EXIT the script:
if [[ ! -f ${ORACLE_HOME}/bin/sqlplus ]]
 then
  echo "Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory in order to get this script to run properly"
  echo "e.g."
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
exit
fi

export LD_LIBRARY_PATH=${ORACLE_HOME}/lib

# ########################################
# Exit if the user is not the Oracle Owner:
# ########################################
CURR_USER=`whoami`
	if [ ${ORA_USER} != ${CURR_USER} ]; then
	  echo ""
	  echo "You're Running This Sctipt with User: \"${CURR_USER}\" !!!"
	  echo "Please Run This Script With The Right OS User: \"${ORA_USER}\""
	  echo "Script Terminated!"
	  exit
	fi

# ###############################
# RMAN: Script Creation:
# ###############################
# Last RMAN Backup Info:
# #####################
export NLS_DATE_FORMAT='DD-Mon-YYYY HH24:MI:SS'
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 170 pages 200
PROMPT
PROMPT LAST 14 DAYS RMAN BACKUP DETAILS:
PROMPT ---------------------------------

set linesize 160
set feedback off
col START_TIME for a15
col END_TIME for a15
col TIME_TAKEN_DISPLAY for a10
col INPUT_BYTES_DISPLAY heading "DATA SIZE" for a10
col OUTPUT_BYTES_DISPLAY heading "Backup Size" for a11
col OUTPUT_BYTES_PER_SEC_DISPLAY heading "Speed/s" for a10
col output_device_type heading "Device_TYPE" for a11
SELECT to_char (start_time,'DD-MON-YY HH24:MI') START_TIME, to_char(end_time,'DD-MON-YY HH24:MI') END_TIME, time_taken_display, status,
input_type, output_device_type,input_bytes_display, output_bytes_display, output_bytes_per_sec_display,COMPRESSION_RATIO COMPRESS_RATIO
FROM v\$rman_backup_job_details
WHERE end_time > sysdate -14;

EOF

# Variables:
export NLS_DATE_FORMAT="DD-MON-YY HH24:MI:SS"

# Check if the DB is in ARCHIVELOG mode:
# ######################################
OPENMODE_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off;
prompt
select STATUS from v\$instance;
exit;
EOF
)

OPENMODE=`echo ${OPENMODE_RAW}| awk '{print $NF}'`

#echo OPENMODE is $OPENMODE

	case ${OPENMODE} in
	STARTED) 
	echo
        echo -e "\033[32;5mThe Instance is in NOMOUNT mode.\033[0m"
	echo
	echo "Please start the instance in MOUNT or OPEN mode."
	echo
	exit
	;;
	OPEN)
ARCHIVEMODE_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off;
prompt
select count(*) from v\$database where LOG_MODE='ARCHIVELOG';
exit;
EOF
)

ARCHIVEMODE=`echo ${ARCHIVEMODE_RAW}| awk '{print $NF}'`
export PLUS_ARCHIVELOG="PLUS ARCHIVELOG"

#echo ARCHIVEMODE is $ARCHIVEMODE

                if [ ${ARCHIVEMODE} -eq 0 ]
                 then
		 echo
		 echo -e "\033[32;5mThe DATABASE is NOT in ARCHIVELOG mode.\033[0m"
		 echo
		 echo "Either bring the instance in the MOUNT mode, or ENABLE the ARCHIVELOG mode."
		 echo
		 exit
                fi
	;;
	MOUNTED)
export PLUS_ARCHIVELOG=""
	;;
	esac


# Building the RMAN BACKUP Script:
# ################################

# Prompt the user for the Backup location:
echo
echo "Enter the BACKUP Location: [e.g. /backup/RMAN]" 
echo "========================="
while read BKPLOCX
do
        case ${BKPLOCX} in
         '') export BKPLOCX=`pwd`;   echo; echo "DIRECTORY TRANSLATED TO: ${BKPLOCX}";;
        '.') export BKPLOCX=`pwd`;   echo; echo "DIRECTORY TRANSLATED TO: ${BKPLOCX}";;
        '~') export BKPLOCX=${HOME}; echo; echo "DIRECTORY TRANSLATED TO: ${BKPLOCX}";;
        esac

        if [[ -d "${BKPLOCX}" ]] && [[ -r "${BKPLOCX}" ]] && [[ -w "${BKPLOCX}" ]]
        then
	# Create the Backup directory:
	export BKPLOC=${BKPLOCX}/RMANBKP_${ORACLE_SID}/`date +%d-%b-%y`
/bin/mkdir -p ${BKPLOC}
	echo
        echo "RMAN Backup will be saved under: ${BKPLOC}"; break
        else
        echo; printf "`echo "Please make sure that oracle user has"` `echo -e "\033[33;5mREAD/WRITE\033[0m"` `echo "permissions on the provided directory."`\n"; echo; 
	echo "Enter the complete PATH where the RMAN Backup will be saved: [e.g. /backup/RMAN]"
	echo "-----------------------------------------------------------"
        fi

done

# Exit if the user press Ctrl+D:
if [[ ! -w "${BKPLOC}" ]]; then
exit
fi

# Check if the recover process is active on a STANDBY DB:
RECNUM=`ps -ef|grep mrp0_${ORACLE_SID}|grep -v grep|wc -l`

	if [ ${RECNUM} -gt 0 ]
	then
	echo
        echo -e "\033[32;5mDetected an Active RECOVERY against the DB\033[0m"
	echo
	echo "Do you want to PAUSE the RECOVERY during the RMAN backup and RESUME it back after the completion of the backup to maintain a consistent backup? [Y|N] [N]"
	echo "==============================================================================================================================================="
	echo "Note: The Standby DB will not be in-sync during the backup if the RECOVERY paused"
	echo ""
	while read CANCEL_RECOVERY
	do
                case ${CANCEL_RECOVERY} in
                  y|Y|yes|YES|Yes)
                  echo
                  echo "RECOVERY will be CANCELED during the backup and will be RESUMED back after it gets complete."
                  echo
                  RECOVERY_STOP="sql \"alter database RECOVER MANAGED STANDBY DATABASE CANCEL\";"
		  RECOVERY_START="sql \"alter database RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE NODELAY PARALLEL ${CPU_NUM} DISCONNECT\";"
                  export RECOVERY_STOP
                  export RECOVERY_START
                  break ;;
                  ""|n|N|no|NO|No) RECOVERY_STOP="";RECOVERY_START="";break ;;
                  *) echo "Please enter a VALID answer: [Y|N]"
		     echo "----------------------------";;
                esac
        done
	fi



# Prompt the user for the number of channels:
echo
echo "How many CHANNELS do you want to allocate for this backup? [${CPU_NUM} CPUs Available On This Machine]"
echo "========================================================="
while read CHANNEL_NUM
	do
		integ='^[0-9]+$'
		if ! [[ ${CHANNEL_NUM} =~ $integ ]] ; then
   			echo "Error: Not a valid number !"
			echo
			echo "Please Enter a VALID NUMBER:"
			echo "---------------------------"
		else
			break
		fi
	done
echo
echo "Number Of Channels is: ${CHANNEL_NUM}"
echo
echo "---------------------------------------------"
echo "COMPRESSED BACKUP will allocate SMALLER space"
echo "but it's a bit SLOWER than REGULAR BACKUP."
echo "---------------------------------------------"
echo
echo "Do you want a COMPRESSED BACKUP? [Y|N]: [Y]"
echo "================================"
while read COMPRESSED
	do
		case $COMPRESSED in  
		  ""|y|Y|yes|YES|Yes) COMPRESSED=" AS COMPRESSED BACKUPSET "; echo "COMPRESSED BACKUP ENABLED.";break ;; 
		  n|N|no|NO|No) COMPRESSED="";break ;; 
		  *) echo "Please enter a VALID answer [Y|N]" ;;
		esac
	done

echo
echo "Do you want to ENCRYPT the BACKUP by Password? [Available in Enterprise Edition only] [Y|N]: [N]"
echo "=============================================="
while read ENCR_BY_PASS_ANS
        do
                case ${ENCR_BY_PASS_ANS} in
                  y|Y|yes|YES|Yes)
		  echo
		  echo "Please Enter the password that will be used to Encrypt the backup:"
		  echo "-----------------------------------------------------------------"
		  read ENCR_PASS
		  ENCR_BY_PASS="SET ENCRYPTION ON IDENTIFIED BY '${ENCR_PASS}' ONLY;"
		  export ENCR_BY_PASS
		  echo
		  echo "BACKUP ENCRYPTION ENABLED."
		  echo
		  echo "Later, To RESTORE this backup please use the following command to DECRYPT it, placing it just before the RESTORE Command:"
		  echo "  e.g."
		  echo "  SET DECRYPTION IDENTIFIED BY '${ENCR_PASS}';"
		  echo "  restore database ...."
		  echo
		  break ;;
                  ""|n|N|no|NO|No) ENCR_BY_PASS="";break ;;
                  *) echo "Please enter a VALID answer [Y|N]" ;;
                esac
        done

RMANSCRIPT=${BKPLOC}/RMAN_FULL_${ORACLE_SID}.rman
RMANSCRIPTRUNNER=${BKPLOC}/RMAN_FULL_nohup.sh
RMANLOG=${BKPLOC}/rmanlog.`date +%d-%b-%y`.log

echo "${ENCR_BY_PASS}"      > ${RMANSCRIPT}
echo "run {" 		   >> ${RMANSCRIPT}
CN=1
while [[ ${CN} -le ${CHANNEL_NUM} ]]
do
echo "allocate channel C${CN} type disk;" >> ${RMANSCRIPT}
    ((CN = CN + 1))
done
echo "CHANGE ARCHIVELOG ALL CROSSCHECK;" >> ${RMANSCRIPT}
#echo "DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;" >> ${RMANSCRIPT}
echo ${RECOVERY_STOP}							    	>> ${RMANSCRIPT}
echo "BACKUP ${COMPRESSED} FORMAT '${BKPLOC}/%d_%I_%t_%s_%p' TAG='FULLBKP'" 	>> ${RMANSCRIPT}
echo "FILESPERSET 100 DATABASE include current controlfile ${PLUS_ARCHIVELOG};" >> ${RMANSCRIPT}
#echo "BACKUP FORMAT '${BKPLOC}/%d_%t_%s_%p.ctl' TAG='CONTROL_BKP' CURRENT CONTROLFILE;" >> ${RMANSCRIPT}
echo "BACKUP ${COMPRESSED} FORMAT '${BKPLOC}/CONTROLFILE_%d_%I_%t_%s_%p.bkp' REUSE TAG='CONTROL_BKP' CURRENT CONTROLFILE;" 	>> ${RMANSCRIPT}
echo ${RECOVERY_START}                                                          >> ${RMANSCRIPT}
echo "SQL \"ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''${BKPLOC}/controlfile.trc'' REUSE\";" 				>> ${RMANSCRIPT}
echo "SQL \"CREATE PFILE=''${BKPLOC}/init${ORACLE_SID}.ora'' FROM SPFILE\";" 	>> ${RMANSCRIPT}
echo "}" 									>> ${RMANSCRIPT}
echo "RMAN BACKUP SCRIPT CREATED."
echo 
sleep 1
echo "Backup Location is: ${BKPLOC}"
echo
sleep 1
echo "Starting Up RMAN Backup Job ..."
echo
sleep 1
echo "#!/bin/bash" > ${RMANSCRIPTRUNNER}
echo "nohup ${ORACLE_HOME}/bin/rman target / cmdfile=${RMANSCRIPT} | tee ${RMANLOG}  2>&1 &" >> ${RMANSCRIPTRUNNER}
chmod 740 ${RMANSCRIPTRUNNER}
source ${RMANSCRIPTRUNNER}
echo
echo " The RMAN backup job is currently running in the background. Disconnecting the current session will NOT interrupt the backup job :-)"
echo " Now, viewing the backup job log:"
echo
echo "Backup Location is: ${BKPLOC}"
echo "Check the LOGFILE: ${RMANLOG}"
echo

# #############
# END OF SCRIPT
# #############
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
##############################################################################################################################
