#!/bin/bash
outgoingDirectory='/nfsshare/public/outgoing';
ftpServer='ftp-internal.provo.novell.com';
ftpServerDirectory='outgoing';
logDirectory='/var/log/nftp';
logFilename='nftp.log';
lftpBookmark='ftpNovell';

touch $logDirectory/history.log
rm `find $logDirectory -name 'history.log' -size +1M` 2>/dev/null

if [ "$(ls -A $outgoingDirectory)" ]; then

	# Get Contents of specified directory
	echo -e "Retrieving local listing from $outgoingDirectory..."
	ls $outgoingDirectory/ | fold > $logDirectory/localList
	
	# Get current list on ftp & cleanup (remove ./ characters)
	echo -e "\nRetrieving remote listing from $ftpServer:/$ftpServerDirectory..."
	lftp "$lftpBookmark" -e "cd $ftpServerDirectory; ls; bye" > $logDirectory/ftpList	
	cat $logDirectory/ftpList | sed -e 's/.\///g' > $logDirectory/ftpList	
	
	# Compare ftp contents with contents
	echo -e "\nDetermining an upload list..."
	grep -Fxvf $logDirectory/ftpList $logDirectory/localList > $logDirectory/diffList

	diffList=`cat $logDirectory/diffList 2>/dev/null`
	fileArray=($diffList);

	# Upload missing files to FTP server
	if [[ ! -z ${fileArray[@]} ]]; then
		echo -e "\nUploading files to ftp..."
		cd $outgoingDirectory
		echo -e "\n${fileArray[@]}\n"

lftp "$lftpBookmark" <<EOF
cd $ftpServerDirectory
mput ${fileArray[@]}; 
bye
EOF
	echo -e `date` "Files uploaded: "${fileArray[@]} >> $logDirectory/$logFilename
	else echo -e `date` "Nothing to upload." >> $logDirectory/$logFilename; echo -e "Nothing to upload."
	fi
else echo -e `date` "No files in outgoing directory." >> $logDirectory/$logFilename
fi
rm -f $logDirectory/localList $logDirectory/ftpList $logDirectory/diffList
exit 0
