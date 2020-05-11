#!/usr/nsh/NSH/bin/nsh
#
# Check the status of a system defined in bladelogic
#
_SERVER_LIST=${1}
_AUTOLIC_USER=kennyh
_AUTOLIC_PASSWD=password

for _server in `echo ${_SERVER_LIST} | sed -e 's/,/ /g'`
do
 echo "****** AGENT INFO of the ${_server} *******"
 if agentinfo ${_server} |grep -i "License Status" |  egrep -i "Not Licensed|Expires" > /dev/null 2>&1
 then
  echo "$_server is on a temp license, going to try and give it a valid license"
  if autolic $_AUTOLIC_USER $_AUTOLIC_PASSWD ${_server} > /dev/null 2>&1
  then
   echo "$_server has been licensed, lets double check the agent status."
   agentinfo ${_server}
  else
   echo "$_server failed to license, please check out why"
  fi
 else
  echo "agent on the server $_server looks good"
 fi
 if blcli -r UK_BLAdmins -v BladeLogic-DCUNX231 Server addServer  $_server
 then
  echo "$_server has been added to bladelogic"
 else
  echo "Failed to add server to bladelogic, please investigate. EXIT1"
  exit 1
 fi
 echo "****** AGENT Status in BladeLogic App Server ********"
 if blcli -r UK_BLAdmins -v BladeLogic-DCUNX231 Server printAllProperties ${_server} | grep -i AGENT_STATUS > /dev/null 2>&1
 then
   echo "Agent properties look good on ${_server}"
 else
   if blcli -r UK_BLAdmins -v BladeLogic-DCUNX231 Utility updateServersStatus ${_server} 20 10000 true
   then
    echo "Did a updateServersStatus of $_server"
   else
    echo "updateServersStatus failed with $_server, investigate"
   fi
 fi
done
