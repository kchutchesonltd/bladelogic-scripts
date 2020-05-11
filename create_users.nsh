#!/usr/nsh/NSH/bin/nsh

_SERVERS="$1"
_SCRIPT=create_users.ksh

for _server in ${_SERVERS}
do
 ncp -v $_SCRIPT -h $_server -d /tmp
 nexec $_server "bash $_SCRIPT"  >> $HOME/${_server}.tmp &
done
