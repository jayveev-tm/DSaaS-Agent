#!/bin/bash

ACTIVATIONURL='dsm://agents.deepsecurity.trendmicro.com:443/'
MANAGERURL='https://app.deepsecurity.trendmicro.com:443'
CURLOPTIONS='--silent --tlsv1.2'
linuxPlatform='';
isRPM='';

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo You are not running as the root user.  Please try again with root privileges.;
    logger -t You are not running as the root user.  Please try again with root privileges.;
    exit 1;
fi;

if type curl >/dev/null 2>&1; then
  CURLOUT=$(eval curl $MANAGERURL/software/deploymentscript/platform/linuxdetectscriptv1/ -o /tmp/PlatformDetection $CURLOPTIONS;)
  err=$?
  if [[ $err -eq 60 ]]; then
     echo "TLS certificate validation for the agent package download has failed. Please check that your Deep Security Manager TLS certificate is signed by a trusted root certificate authority. For more information, search for \"deployment scripts\" in the Deep Security Help Center."
     logger -t TLS certificate validation for the agent package download has failed. Please check that your Deep Security Manager TLS certificate is signed by a trusted root certificate authority. For more information, search for \"deployment scripts\" in the Deep Security Help Center.
     exit 2;
  fi

  if [ -s /tmp/PlatformDetection ]; then
      . /tmp/PlatformDetection
      platform_detect

      if [[ -z "${linuxPlatform}" ]] || [[ -z "${isRPM}" ]]; then
         echo Unsupported platform is detected
         logger -t Unsupported platform is detected
         false
      else
         echo Downloading agent package...
         if [[ $isRPM == 1 ]]; then package='agent.rpm'
         else package='agent.deb'
         fi
         curl -H "Agent-Version-Control: on" $MANAGERURL/software/agent/${runningPlatform}${majorVersion}/${archType}/$package?tenantID=63690 -o /tmp/$package $CURLOPTIONS

         echo Installing agent package...
         rc=1
         if [[ $isRPM == 1 && -s /tmp/agent.rpm ]]; then
           rpm -ihv /tmp/agent.rpm
           rc=$?
         elif [[ -s /tmp/agent.deb ]]; then
           dpkg -i /tmp/agent.deb
           rc=$?
         else
           echo Failed to download the agent package. Please make sure the package is imported in the Deep Security Manager
           logger -t Failed to download the agent package. Please make sure the package is imported in the Deep Security Manager
           false
         fi
         if [[ ${rc} == 0 ]]; then
           echo Install the agent package successfully

            sleep 15
            /opt/ds_agent/dsa_control -r
            /opt/ds_agent/dsa_control -a $ACTIVATIONURL "tenantID:7014C2B7-0A58-F04D-9026-B497235D0E61" "token:13D37D80-354C-B247-8603-3FD2E401E017" "policyid:8"
            # /opt/ds_agent/dsa_control -a dsm://agents.deepsecurity.trendmicro.com:443/ "tenantID:7014C2B7-0A58-F04D-9026-B497235D0E61" "token:13D37D80-354C-B247-8603-3FD2E401E017" "policyid:8"
       else
           echo Failed to install the agent package
           logger -t Failed to install the agent package
           false
         fi
      fi
  else
     echo "Failed to download the agent installation support script."
     logger -t Failed to download the Deep Security Agent installation support script
     false
  fi
else 
  echo "Please install CURL before running this script."
  logger -t Please install CURL before running this script
  false
fi
