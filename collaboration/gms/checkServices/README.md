# checkServices
Alert Notification System for DataSync/Mobility Administration

Notification service if any DataSync services/connectors go offline. The script restarts the services if any are found to be in a dead/unused state and sends an email to the administrator defined in the script file. The notification email contains the following information:
<ul>
<li>hostname of server</li>
<li>date/time when services were found offline</li>
<li>the list of services found offline</li>
<li>status of services after a restart attempt</li>
<li>the current log levels</li>
<li>an attachment with a copy of all the logs and other server information</li>
</ul>
Running the script manually displays the following and will appear in the notification email:

```
Checking for DataSync Config Engine:        running
Checking for DataSync Web Admin:            running
Checking for DataSync Connector Manager:    running
Checking for DataSync Engine:               running
Mobility Connector listening on port 443:   true
GroupWise Connector listening on port 4500: true
```

When implemented with crontab, the script can be set to run every hour, for example. This allows an administrator to be notified of a failure before users complain. Edit the script file and replace email@address.com with the desired administrator’s email. You can likewise configure a list of email address by placing them in single quotes separated by a comma and a space – ‘email1, email2, email3′

To run the script regularly with crontab, just place the script file into /etc/cron.hourly to run hourly or /etc/cron.daily to run daily. Custom definitions can be made by editing the crontab file manually:

```bash
crontab -e
```

An example of running the script every 30 minutes:
```bash
0/30 * * * * /root/scripts/checkServices.sh
```
