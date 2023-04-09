# oracle_rman_backup
This script takes an on-demand RMAN Backup

````sql
[oracle@localhost ~]$ sh rman_bkp.sh

===================================================
This script Takes a RMAN FULL Backup of a database.
===================================================


Select the ORACLE_SID:[Enter the number]
---------------------
1) ORCL21C
2) TEST
#? 3

Error: Not a valid number!

Enter a valid NUMBER from the displayed list !: i.e. Enter a number from [1 to 2]
----------------------------------------------
#? 1

Selected Instance: [ ORCL21C ]


LAST 14 DAYS RMAN BACKUP DETAILS:
--------------------------------

Enter the BACKUP Location: [e.g. /backup/RMAN]
=========================
/u02/Backup

RMAN Backup will be saved under: /u02/Backup/RMANBKP_ORCL21C/10-Apr-23

How many CHANNELS do you want to allocate for this backup? [0 CPUs Available On This Machine]
=========================================================
4

Number Of Channels is: 4

---------------------------------------------
COMPRESSED BACKUP will allocate SMALLER space
but it's a bit SLOWER than REGULAR BACKUP.
---------------------------------------------

Do you want a COMPRESSED BACKUP? [Y|N]: [Y]
================================
N

Do you want to ENCRYPT the BACKUP by Password? [Available in Enterprise Edition only] [Y|N]: [N]
==============================================
N
RMAN BACKUP SCRIPT CREATED.

Backup Location is: /u02/Backup/RMANBKP_ORCL21C/10-Apr-23

Starting Up RMAN Backup Job ...


 The RMAN backup job is currently running in the background. Disconnecting the current session will NOT interrupt the backup job :-)
 Now, viewing the backup job log:

Backup Location is: /u02/Backup/RMANBKP_ORCL21C/10-Apr-23
Check the LOGFILE: /u02/Backup/RMANBKP_ORCL21C/10-Apr-23/rmanlog.10-Apr-23.log

````
