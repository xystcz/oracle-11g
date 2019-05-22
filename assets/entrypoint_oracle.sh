#!/usr/bin/env bash

set -e
source /assets/colorecho

alert_log="$ORACLE_BASE/diag/rdbms/$ORACLE_SID/$ORACLE_SID/trace/alert_$ORACLE_SID.log"
listener_log="$ORACLE_BASE/diag/tnslsnr/$HOSTNAME/listener/trace/listener.log"
pfile=$ORACLE_HOME/dbs/init$ORACLE_SID.ora

# monitor $logfile
monitor() {
    tail -F -n 0 $1 | while read line; do echo -e "$2: $line"; done
}


trap_db() {
	trap "echo_red 'Caught SIGTERM signal, shutting down...'; stop" SIGTERM;
	trap "echo_red 'Caught SIGINT signal, shutting down...'; stop" SIGINT;
}

start_db() {
	echo_yellow "Starting listener..."
	monitor $listener_log listener &
	lsnrctl start | while read line; do echo -e "lsnrctl: $line"; done
	MON_LSNR_PID=$!
	echo_yellow "Starting database..."
	trap_db
	monitor $alert_log alertlog &
	MON_ALERT_PID=$!
	sqlplus / as sysdba <<-EOF |
		pro Starting with pfile='$pfile' ...
		startup;
		alter system register;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
	wait $MON_ALERT_PID
}

create_db() {
	echo_yellow "Database does not exist. Creating database..."
	date "+%F %T"
	monitor $alert_log alertlog &
	MON_ALERT_PID=$!
	monitor $listener_log listener &
	#lsnrctl start | while read line; do echo -e "lsnrctl: $line"; done
	#MON_LSNR_PID=$!
        echo "START DBCA"
	dbca -silent -createDatabase -responseFile /assets/dbca.rsp
	sed -i 's/MK_EMAGENT_NMECTL)/MK_EMAGENT_NMECTL)\ -lnnz11/g' $ORACLE_HOME/sysman/lib/ins_emagent.mk
	make -f $ORACLE_HOME/sysman/lib/ins_emagent.mk agent nmhs >> "${alert_log}" 2>&1
	echo_green "Database created."
	date "+%F %T"
        touch $pfile
	trap_db
        kill $MON_ALERT_PID
	#wait $MON_ALERT_PID
}

stop() {
    trap '' SIGINT SIGTERM
	shu_immediate
	echo_yellow "Shutting down listener..."
	lsnrctl stop | while read line; do echo -e "lsnrctl: $line"; done
	kill $MON_ALERT_PID $MON_LSNR_PID
	exit 0
}

shu_immediate() {
	ps -ef | grep ora_pmon | grep -v grep > /dev/null && \
	echo_yellow "Shutting down the database..." && \
	sqlplus / as sysdba <<-EOF |
		set echo on
		shutdown immediate;
		exit 0
	EOF
	while read line; do echo -e "sqlplus: $line"; done
}

echo "Checking shared memory..."
df -h | grep "Mounted on" && df -h | egrep --color "^.*/dev/shm" || echo "Shared memory is not mounted."
if [ ! -f $pfile ]; then
  create_db;
fi 
start_db
