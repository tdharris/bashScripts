#!/bin/bash
outgoingDirectory='/wrk/outgoing';
ftpServer='ftp-internal.provo.novell.com';
ftpServerDirectory='outgoing';
logDirectory='/usr/nftp';

source /etc/profile.local

touch $logDirectory/history.log
rm `find $logDirectory -name 'history.log' -size +1M` 2>/dev/null

if [ "$(ls -A $outgoingDirectory)" ]; then

	# Get Contents of specified directory
	ls $outgoingDirectory/ | fold > $logDirectory/localList
	
	# Get current list on ftp
	lftp -e 'find; bye' ftp.novell.com:/$ftpServerDirectory > $logDirectory/ftpList	
	
	# Get file name, and replace ftpList
	cat $logDirectory/ftpList | cut -f2 -d '/' > $logDirectory/ftpList2; mv $logDirectory/ftpList2 $logDirectory/ftpList

	# Compare ftp contents with contents
	while read -r line
	do
		grepVar=`grep -oi "$line" $logDirectory/ftpList`
		if [ -z "$grepVar" ];then
			echo "$line" >> $logDirectory/diffList
		fi
	done < $logDirectory/localList

	diffList=`cat $logDirectory/diffList 2>/dev/null`
	fileArray=($diffList);

	# Upload missing files to FTP server
	if [[ ! -z ${fileArray[@]} ]]; then
		cd $outgoingDirectory
		echo -e "\n${fileArray[@]}\n"
	# nlftp command is defined in /root/bin/nlftp		
nlftp <<EOF
cd $ftpServerDirectory
mput ${fileArray[@]}; 
bye
EOF
		echo -e `date` "Files uploaded: "${fileArray[@]} >> $logDirectory/history.log
	else echo -e `date` "Nothing to upload." >> $logDirectory/history.log; echo -e "Nothing to upload."
	fi
else echo -e `date` "No files in outgoing directory." >> $logDirectory/history.log
fi
rm -f $logDirectory/localList $logDirectory/ftpList $logDirectory/diffList
exit 0
