#!/bin/ksh
# set -x

if [ ! -r ~/.bladelogic/.user/user_info.dat ]
then
   echo "User information file must be created first."
   if [ ! -d  ~/.bladelogic ]
   then
      mkdir  ~/.bladelogic
      chmod 700 ~/.bladelogic
   fi
   if [ ! -d  ~/.bladelogic/.user ]
   then
      mkdir ~/.bladelogic/.user
      chmod 700 ~/.bladelogic/.user
   fi
   cd ~/.bladelogic/.user/
   echo "\nAnswer user_info.dat for file name."
   echo "Answer with BladeLogic user name."
   echo "Answer with BladeLogic password."
   echo "Answer with BladeLogic role.\n"
   sleep 5
   /usr/nsh/NSH/br/bl_gen_blcli_user_info
   cd
   if [ $? -ne 0 ]
   then
      echo "Unable to create user information file.  Exiting."
      exit 10
   fi
fi

echo "Using ~/.bladelogic/.user/user_info.dat for authentication.  If incorrect, please delete."

/usr/nsh/NSH/br/blcred cred -acquire -profile BladeLogic-DCUNX231 -i ~/.bladelogic/.user/user_info.dat
/bin/nsh
