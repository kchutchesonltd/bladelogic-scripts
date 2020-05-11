#!/usr/nsh/NSH/bin/nsh
_SERVERS=${1}
_AUTO_JOB_FOLDER="/UNIX/Dynamic"
_DEP_FOLDER="/UNIX/EDC Localisation"
_AUTO_FOLDER_ID=`blcli JobGroup groupNameToId $_AUTO_JOB_FOLDER`
_UPDATE_SERVER="UKASBLREP01"
_DB_UPD_CMD="C:\\Windows\\System32\\cscript.exe //nologo e:\\Localstuff\\ShawnsAmazingUpdateScript\\UpdateEDC.vbs"
_EXT=`date +%y%m%d%H%M%S`
_BLWEBUSER="cblanks"
_BLWEBPASS="sc0rp10"
_counter=1


_PKGS[1]="BlPackage:Linux AGNlocal RPM install:/tmp/AGNlocal.out"
_PKGS[2]="BlPackage:Linux Patrol RPM install:/tmp/AGNpatrol.out"
_PKGS[3]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_setup_resolv_conf:/tmp/AGNlocal_resolv.out:ALL AGNlocal EDC_Setup_Resolv_config"
_PKGS[4]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_setup_satellite:/tmp/AGNlocal_satellite.out:Linux AGNlocal EDC_Setup_satellite"
_PKGS[5]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_setup_hosts:/tmp/AGNlocal_hosts.out:ALL AGNlocal EDC_Setup_Etc_Hosts"
_PKGS[6]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_setup_tsm_client:/tmp/AGNlocal_tsm.out:ALL AGNlocal EDC_Setup_tsm_client"
_PKGS[7]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_setup_ntpd:/tmp/AGNlocal_ntpd.out:ALL AGNlocal EDC_Setup_ntpd"
_PKGS[8]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_setup_sudoers:/tmp/AGNlocal_sudoers.out:ALL AGNlocal EDC_Setup_sudoers"
_PKGS[9]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_disable_tivoli:/tmp/AGNlocal_tivoli.out:ALL AGNlocal EDC_disable_tivoli"
_PKGS[10]="BlPackage:AGNnmon - Linux Filesystem Creation:/tmp/AGNnmon.out"
_PKGS[11]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_setup_supp_users:/tmp/AGNlocal_users.out:ALL AGNlocal EDC_Setup_Support_Users"
_PKGS[12]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_install_dependancies:/tmp/AGNlocal_dependancies.out:Linux AGNlocal edc_install_dependancies"
_PKGS[13]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_setup_krb5:/tmp/AGNlocal_kerberos.out:Linux AGNlocal EDC_Setup_Kerberos"
_PKGS[14]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_setup_mondorescue:/tmp/AGNlocal_mondo.out:Linux AGNlocal EDC_Setup_MondoRescue"
_PKGS[15]="BlPackage:Linux AGNoraprep RPM install:/tmp/AGNoraprep.out"
_PKGS[16]="BlPackage:Linux AGNwiprep RPM install:/tmp/AGNwiprep.out"
_PKGS[17]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_remove_routes:/tmp/AGNlocal_routes.out:Linux AGNlocal edc_remove_routes"
_PKGS[18]="NSH:/opt/AGNlocal/bin/EDC_Localisation -t edc_remove_opsware:/tmp/AGNlocal_opsware.out:ALL AGNlocal EDC_remove_opsware"

_number_of_PKGS=${#_PKGS[*]}

function check_server_status
{
 _TARGET_SERVER=$1
 if agentinfo ${_TARGET_SERVER} |grep -i "License Status" |  egrep -i "Not Licensed|Expires" > /dev/null 2>&1
 then
  if autolic ${_BLWEBUSER} ${_BLWEBPASS} ${_TARGET_SERVER} > /dev/null 2>&1
  then
   echo "INFO: ${_TARGET_SERVER} has been licensed"
   if blcli Server printAllProperties ${_TARGET_SERVER} | grep -i AGENT_STATUS > /dev/null 2>&1
   then
    echo "INFO: Agent properties look good on ${_TARGET_SERVER}"
    return 0
   else
    if blcli Utility updateServersStatus ${_TARGET_SERVER} 20 10000 true
    then
     echo "INFO: Did a updateServersStatus of ${_TARGET_SERVER}"
     return 0
    else
     echo "ERROR: updateServersStatus failed with ${_TARGET_SERVER}, investigate"
     exit 1
    fi
   fi
  else
   echo "ERROR: ${_TARGET_SERVER} failed to license, please check out why"
   exit 1
  fi
 fi
}

function update_db_status
{
   _FQDN=${1}
   _MESSAGE=${2}

   nexec -l $_UPDATE_SERVER $_DB_UPD_CMD \"$_FQDN\" \"$_MESSAGE\"
}

# THis function is to check the IP address and if the system is a physical server,
# it will then update the migration DB to inform the user that there may be manual interaction required
# to add additional ip addresses or setup network bonding.

function system_network_check
{
_SERVERS="$1"

for _server_name in ${_SERVERS}
do
 _server=`echo $_server_name | awk -F'.' '{print $1}'`
 # Hack cos SRV21271 our test clone has _ instead of . as a delimeter
 if [[ ${_server_name} == "SRV21271_VM_CLONE" ]]
 then
        _server=SRV21271
 fi
 _counter=0
 _VM_OR_PHYS_counter=0
 _num_of_elements=0
 nexec -l UKASBLREP01 /C/Windows/System32/cscript.exe //nologo E:/\/\Localstuff/\/\Unix/\/\MigDbIpLookup.vbs ${_server} | tr '[:upper:]' '[:lower:]' > /tmp/$$.${_server}
 set -A _SERVER_NAME
 set -A _SOURCE_IP
 set -A _BUBBLE_IP
 set -A _BUBBLE_VLAN
 set -A _PRODUCTION_IP
 set -A _PROD_VLAN
 set -A _MIG_GROUP
 set -A _VM_OR_PHYS

 case $? in
  1) echo "ERROR: No Argument was sent to the MigDBIpLookup.vbs script, server name has to be sent"
     exit 1
     ;;
  2) echo "ERROR: No records found for server ${_server}"
     exit 2
     ;;
  3) echo "ERROR: Unable to connect to SQL database ukdbmdb01.ds.global"
     exit 3
     ;;
 esac

 while read _line
 do
   _SERVER_NAME[${_counter}]=`echo ${_line} | awk -F';' '{print $1}'`
   _SOURCE_IP[${_counter}]=`echo ${_line} | awk -F';' '{print $2}'`
   _BUBBLE_IP[${_counter}]=`echo ${_line} | awk -F';' '{print $3}'`
   _BUBBLE_VLAN[${_counter}]=`echo ${_line} | awk -F';' '{print $4}'`
   _PRODUCTION_IP[${_counter}]=`echo ${_line} | awk -F';' '{print $5}'`
   _PROD_VLAN[${_counter}]=`echo ${_line} | awk -F';' '{print $6}'`
   _MIG_GROUP[${_counter}]=`echo ${_line} | awk -F';' '{print $8}'`
   _VM_OR_PHYS[${_counter}]=`echo ${_line} | awk -F';' '{print $9}'  |tr -d '\r'`
   if [[ $_VM_OR_PHYS  == no ]]
   then
      ((_VM_OR_PHYS_counter=_VM_OR_PHYS_counter+1))
   fi
   ((_counter=_counter+1))
 done < /tmp/$$.${_server}

 _num_PRODIP_elements=${#_PRODUCTION_IP[*]}

 _VM_or_PHYS=`echo ${_VM_OR_PHYS[@]} | sort -u`

 if [[ "${_VM_OR_PHYS_counter}" -eq 0 ]]
 then
    update_db_status $_server_name "MANUAL INTERVENTION: ${_server} is a physical server located in ${_VM_or_PHYS} you need to setup bonding eth0 & eth1 to bond0"
 fi

 if [[ $_num_PRODIP_elements -gt 1 ]]
 then
    update_db_status $_server_name "MANUAL INTERVENTION: ${_server} has multiple IP Addresses </br> ${_PRODUCTION_IP[@]} you will need to create the relevant files in /etc/sysconfig/network-scripts/ etc"
 fi
 [[ -f /tmp/$$.${_server} ]] && rm /tmp/$$.${_server}
done
}

function execute_bl_package_deploy_job
{
   _PACKAGE_NAME="${1}"
   _DEPOT_GROUP_NAME="${2}"
   _JOB_GROUP_NAME="${3}"
   _JOB_NAME="${4}"
   _TARGET_SERVER="${5}"

if [[ -f "//${_TARGET_SERVER}${_TMP_LOG}" ]]
then
        update_db_status $_TARGET_SERVER "${_JOB_NAME} was run previously no need to run again success"
        return 0
else


   update_db_status $_TARGET_SERVER "Starting ${_JOB_NAME}"

   SIMULATE=false
   COMMIT=true
   INDIRECT=true

   DEPLOY_OPTS="$SIMULATE $COMMIT $INDIRECT"

   PACKAGE_KEY=`blcli BlPackage getDBKeyByGroupAndName "$_DEPOT_GROUP_NAME" "$_PACKAGE_NAME"`
   GROUP_ID=`blcli JobGroup groupNameToId "${_JOB_GROUP_NAME}"`
   DEPLOY_JOB_KEY=`blcli DeployJob createDeployJob "${_JOB_NAME}" $GROUP_ID $PACKAGE_KEY $_TARGET_SERVER $DEPLOY_OPTS`
   JUNK=`blcli DeployJob setOverriddenParameterValue "${_JOB_GROUP_NAME}" "${_JOB_NAME}" AUTO_GENERATED "True"`
   JOB_RUN_KEY=`blcli DeployJob executeJobAndWait $DEPLOY_JOB_KEY`
   HAS_ERRORS=`blcli JobRun getJobRunHadErrors $JOB_RUN_KEY`

   if [[ "$HAS_ERRORS" == "false" ]]
   then
       update_db_status $_TARGET_SERVER "Ending ${_JOB_NAME} reported success"
       echo "Starting ${_JOB_NAME} on $_TARGET_SERVER"
   else
      if [[ -f "//${SERVER}${_TMP_LOG}" ]]
      then
        _MSG=`cat //${SERVER}${_TMP_LOG}`
      else
        _MSG="TMP Log file doesn't exists can't tell you what the error was"
      fi
      update_db_status $_TARGET_SERVER "Ending ${_JOB_NAME} reported failure </br> ERROR MSG: </br> ${_MSG}"
      echo "Ending ${_JOB_NAME} reported failure \n ERROR MSG: \n\n ${_MSG}\n"
      if [[ ${_counter} -eq '1' ]]
      then
        update_db_status "$SERVER" "Process Failed"
        exit 1
      fi
   fi
fi
}
function execute_nsh_job
{
 _REMOTE_COMMAND="$1"
 _TARGET_SERVER="$2"
 _LOG_FILE="$3"
 _JOB_NAME="$4"


if [[ -f "//${_TARGET_SERVER}${_TMP_LOG}" ]]
then
        echo "${_JOB_NAME} already been run reported success"
else
 update_db_status $_TARGET_SERVER "Starting ${_JOB_NAME}"
 echo "Starting ${_JOB_NAME} on $_TARGET_SERVER"
if check_server_status "${_TARGET_SERVER}"
then
 if nexec "${_TARGET_SERVER}" "${_REMOTE_COMMAND} > ${_LOG_FILE} 2>&1"
 then
   update_db_status $_TARGET_SERVER "Ending ${_JOB_NAME} reported success"
   echo "Ending ${_JOB_NAME} reported success on $_TARGET_SERVER"
 else
   if [[ -f "//${_TARGET_SERVER}${_TMP_LOG}" ]]
   then
       _MSG=`cat //${_TARGET_SERVER}${_TMP_LOG}`
   else
       _MSG="TMP Log file doesn't exists can't tell you what the error was"
   fi
   update_db_status $_TARGET_SERVER "Ending ${_JOB_NAME} reported failure RETURN=${_RET_CODE} </br> ERROR MSG: </br> ${_MSG}"
   echo "Ending ${_JOB_NAME} reported failure RETURN=${_RET_CODE} \n\n ${_MSG}\n\n"
 fi
else
 update_db_status $_TARGET_SERVER "Exited because the $_TARGET_SERVER is no longer licensed in BladeLogic. ${_JOB_NAME} should just be run manually"
 echo "Exited because the $_TARGET_SERVER is no longer licensed in BladeLogic. ${_JOB_NAME} should just be run manually"
fi
fi
}

function multithread_job
{
 if [[ "${_RUN_TYPE}" == "NSH" ]]
 then
   execute_nsh_job "${_RUN_JOB}" "$SERVER" "${_TMP_LOG}" "${_counter} - ${_JOB_NAME}"
 elif [[ "${_RUN_TYPE}" == "BlPackage" ]]
 then
   execute_bl_package_deploy_job "${_RUN_JOB}" "$_DEP_FOLDER" "$_AUTO_JOB_FOLDER/$SERVER" "${_counter} - ${_RUN_JOB}.$SERVER.$_EXT" "$SERVER"
 fi
}

function multithread_servers
{
 JOB_GROUP1="$SERVER"
 JOB_GROUP1_ID=`blcli JobGroup createJobGroup $JOB_GROUP1 $_AUTO_FOLDER_ID`

 update_db_status "$SERVER" "Process Starting: ${_number_of_PKGS} steps in total"
 system_network_check ${SERVER}
 while [[ ${_counter} -le ${_number_of_PKGS} ]]
 do
  _RUN_TYPE=`echo ${_PKGS[${_counter}]} | awk -F':' '{print $1}'`
  _RUN_JOB=`echo ${_PKGS[${_counter}]} | awk -F':' '{print $2}'`
  _TMP_LOG=`echo ${_PKGS[${_counter}]} | awk -F':' '{print $3}'`
  _JOB_NAME=`echo ${_PKGS[${_counter}]} | awk -F':' '{print $4}'`

   multithread_job
  ((_counter=_counter+1))
 done
}

# Simple for loop that goes through the server list then calls multithread job that then in turn runs jobs on the servers.
for SERVER in ${_SERVERS}
do
 check_server_status ${SERVER}
 multithread_servers &
done
