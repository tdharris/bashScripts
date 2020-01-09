@echo off

set manager_ip=10.71.16.90
set manager_username=admin
set manager_password=novell123

:: get ipv4
ipconfig | findstr IPv4 > ipadd.txt

:: For statement to find the I.P address
for /F "tokens=14" %%i in (ipadd.txt) do ( 
@echo I.P Address of this host is : %%i 
del ipadd.txt /Q

echo Public IP is: %IP%


@echo Hostname of this host is    : %COMPUTERNAME%
@echo "This Host will be registered to PAM Manager with arguments : %manager_ip% 29120 %%i %COMPUTERNAME% %manager_username% %manager_password% 1"

start "" "c:\Program files\NetIQ\npum\bin\unifi.exe"  regclnt register %manager_ip% 29120 %%i %COMPUTERNAME% %manager_username% %manager_password% 0"
PING -n 15 127.0.0.1>nul 
)

