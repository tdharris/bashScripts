#!/bin/sh
PATH=$PATH:/usr/sbin/

# Specify email address:
email='user@domain.com';

# Check Services
status=true;
failure="";
function checkStatus {
	/usr/sbin/rcdatasync-$1 status
	if [ $? != 0 ] 
		then status=false;
		failure+="$1. "
	fi
} 

function checkMobility {
	port=`grep -i "<listenPort>" /etc/datasync/configengine/engines/default/pipelines/pipeline1/connectors/mobility/connector.xml | sed 's/<[^>]*[>]//g' | tr -d ' '`;
	netstat -patune | grep -i ":$port" | grep -i listen > /dev/null
	if [ $? != 0 ] 
		then status=false;
		failure+="mobility-connector ($port). "
	fi
	echo "Mobility Connector listening on port $port: $status"
} 

function checkGroupWise {
	port=`grep -i "<port>" /etc/datasync/configengine/engines/default/pipelines/pipeline1/connectors/groupwise/connector.xml | sed 's/<[^>]*[>]//g' | tr -d ' '`;
	netstat -patune | grep -i ":$port" | grep -i listen > /dev/null
	if [ $? != 0 ] 
		then status=false;
		failure+="groupwise-connector ($port). "
	fi
	echo "GroupWise Connector listening on port $port: $status"
}
checkStatus configengine
checkStatus webadmin
checkStatus connectors
checkStatus syncengine
if (sed -n '4p' /etc/datasync/monitorengine/monitorengine.xml 2>/dev/null | grep -i true) then
	# Global Status Monitor is enabled
	checkStatus monitorengine
fi
checkMobility
checkGroupWise
 	if (! $status) then
 		echo ""
		mkdir /var/log/datasync/checkServices 2>/dev/null;
		temp="/var/log/datasync/checkServices";
		cd $temp; mkdir connectors configengine syncengine webadmin monitorengine;
		logd="/var/log/datasync"
	# Restart Services and create message body
	 	rcgms stop; killall -9 python 2>/dev/null; rcpostgresql restart; rcgms start;
		echo -e "\nThe following services were found to be in an unused or dead state on $(date):\n$failure\n\nDon't worry, DataSync services were restarted automatically.\nLog files are attached in case you want to investigate the issue.\n\nStatus of Mobility Server after restart:" > $temp/check_services.txt;
		sleep 5;
		status=true;
	 	rcpostgresql status >> $temp/check_services.txt;
		rcgms status >> $temp/check_services.txt;
		checkMobility >> $temp/check_services.txt;
		checkGroupWise >> $temp/check_services.txt;
		echo -e "\nLogging Levels indicated below:" >> $temp/check_loggingLevels.txt;

		etc="/etc/datasync"

		echo -e "Monitor Engine:" >> $temp/check_loggingLevels.txt;
		sed -n '/<log>/,$p; /<\/log>/q' $etc/monitorengine/monitorengine.xml 2>/dev/null | egrep 'level|verbose' >> $temp/check_loggingLevels.txt;

		echo -e "Config Engine:" >> $temp/check_loggingLevels.txt;
		sed -n '/<log>/,$p; /<\/log>/q' $etc/configengine/configengine.xml | egrep 'level|verbose' >> $temp/check_loggingLevels.txt;

		echo -e "Sync Engine Connectors:" >> $temp/check_loggingLevels.txt;
		sed -n '/<log>/,$p; /<\/log>/q' $etc/syncengine/connectors.xml | egrep 'level|verbose' >> $temp/check_loggingLevels.txt;

		echo -e "Sync Engine:" >> $temp/check_loggingLevels.txt;
		sed -n '/<log>/,$p; /<\/log>/q' $etc/syncengine/engine.xml | egrep 'level|verbose' >> $temp/check_loggingLevels.txt;

		echo -e "WebAdmin:" >> $temp/check_loggingLevels.txt;
		sed -n '/<log>/,$p; /<\/log>/q' $etc/webadmin/server.xml | egrep 'level|verbose' >> $temp/check_loggingLevels.txt;

	# Get Attachment Content
		sizelimit=20480000
		postconf -e "message_size_limit = $sizelimit"
		echo -e "\nCreating attachment for report..."		
		logs_datasync="datasync_status";
		logs_connectors="connectors/default.pipeline1.*.log";
		logs_configengine="configengine/configengine.log";
		logs_syncengine="syncengine/connectorManager.log syncengine/engine.log";
		logs_webadmin="webadmin/server.log";
		logs_monitorengine="monitorengine/monitor.log monitorengine/systemagent.log";
		cd $logd
		cp $logs_datasync $temp 2>/dev/null;
		cp $logs_connectors $temp/connectors 2>/dev/null;
		cp $logs_configengine $temp/configengine 2>/dev/null;
		cp $logs_syncengine $temp/syncengine 2>/dev/null;
		cp $logs_webadmin $temp/webadmin 2>/dev/null;
		cp $logs_monitorengine $temp/monitorengine 2>/dev/null;

		cd $temp;
		cat /opt/novell/datasync/version > check_version.txt;
		rpm -qa | grep -i postgres >> check_version.txt;
		rpm -qa | grep -i datasync >> check_version.txt;
		cat /etc/*release >> check_version.txt;
		tar czPf MobilityLogs.tgz *;

	# Email report
		echo -e "\nNotifying $email"
		filesize=`stat -c %s $temp/MobilityLogs.tgz`
		if [ $filesize -lt $sizelimit ]
			then cat $temp/check_services.txt | mail -s "WARNING: Mobility services have been restarted on $(hostname)" -a $temp/MobilityLogs.tgz $email
			else echo -e "\nLogs not attached (> 20MB)" >> $temp/check_services.txt; cat $temp/check_services.txt | mail -s "WARNING: Mobility services have been restarted on $(hostname)" $email
		fi
	# Cleanup
		 rm -R $temp;
	fi
