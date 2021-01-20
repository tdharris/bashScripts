#!/usr/bin/expect -f

set SERVER [lindex $argv 0]
set PORT [lindex $argv 1]
set USER [lindex $argv 2]
set PASSWORD [lindex $argv 3]

set timeout 10
set PROMPT "> "

spawn sftp -o "StrictHostKeyChecking=no" -P $PORT "$USER@$SERVER"

expect {
  timeout { send_user "\nERROR: Timeout Exceeded - Check Host\n"; exit 1 }
  eof { send_user "\nERROR: SFTP Connection Failed!\n"; exit 1 }
  "Enter passphrase for key*" {
    send "\r"
    exp_continue
  }
  "*assword: " {
     send "$PASSWORD\r"
     exp_continue
  }
  "$PROMPT" {}
  "*" {}
}

interact
