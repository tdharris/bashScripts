# nftp
A script to synchronize local folder with internal ftp server

### Installation
1. Configure lftp to ignore certificate:
`echo "set ssl:verify-certificate no" >> ~/.lftp/rc`
2. Setup an lftp bookmark and save your password/credential:
  * `lftp ftp://<userid>@ftp-internal.provo.novell.com/`
  * `set bmk:save-passwords true`
  * `bookmark add ftpNovell`
3. Verify it works:
`lftp ftpNovell`
4. Configure variables in the script for your environment:
  - outgoingDirectory
  - ftpServer
  - logDirectory
  - logFilename
  - lftpBookmark
5. Automate sync (every hour) of local target directory and remote directory on target ftp server:
  * `crontab -e`
  * Append the following line (replace with appropriate path): `* 1 * * * <absolute path to nftp.sh>`
