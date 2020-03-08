#!/bin/bash
#            _ __ _
#        ((-)).--.((-))
#        /     ''     \
#       (   \______/   )
#        \    (  )    /
#        / /~~~~~~~~\ \
#   /~~\/ /          \ \/~~\
#  (   ( (            ) )   )
#   \ \ \ \          / / / /
#   _\ \/  \.______./  \/ /_
#   ___/ /\__________/\ \___
#  *****************************
#  Frogg - admin@frogg.fr
#  http://github.com/FroggDev/zabbix-smb
#  *****************************

##########
# PARAMS #
##########
# Action for the script
SMBACTION=$1
# SMB Server IP
SMBSERVER=$2
# SMB formated share list 
# ex: action=share share1;share2;share3
# ex: action=right share1|user1:pass1+r;share1|user2:pass2+w
SMBSHARES=$3

##########
# CONSTS #
##########
#Element separator
declare -r SEP=";"
#Share separator
declare -r SSEP="|"
#User separator
declare -r USEP=":"
#Right separator
declare -r RSEP="+"

#########
# FUNCS #
#########

# ---
# Get the SMB shares of a server
# @param serverIP
# @param shareList
# @return smb shares not found
function checkSmbShares()
{
# Init result (empty by default = ok)
RESULT=""

# get all SMB share for the server
SMBSHARESFOUND=$(getSmbShares "$1")

# get all SMB share sent by user separated by ;
SMBSHARES=$(echo $2 | tr "$SEP" "\n")

# For each SMB share test if exist in server SMB share list
for SHARE in ${SMBSHARES[@]}
do
  # Check if SMB share does not exist in SMB server shares
  if [[ ! " ${SMBSHARESFOUND[@]} " =~ " ${SHARE} " ]]; then
    RESULT="${RESULT}[${SHARE}]"
  fi
done

# Return 0 if all is ok else the string to display
[[ $RESULT = "" ]] && echo "0" || echo $RESULT
}

# ---
# Get the SMB shares of a server
# @param serverIP
# @param shareList
# @return smb shares not found
function checkSmbRights()
{
RESULT=""

SHAREINFOS=$(echo $2 | tr "$SEP" "\n")
for SHAREINFO in $SHAREINFOS
do
  #DATAS = share|user:pass
  DATAS=$(getElementAt "$SHAREINFO" "$RSEP" 1)
  RIGHT=$(getElementAt "$SHAREINFO" "$RSEP" 2)

  SHARE=$(getElementAt "$DATAS" "$SSEP" 1)
  #USERS = user:pass
  USERS=$(getElementAt "$DATAS" "$SSEP" 2)

  USER=$(getElementAt "$USERS" "$USEP" 1)
  PASS=$(getElementAt "$USERS" "$USEP" 2)

  #Set USER=anonymous if no user set
  [ "$USER" = "" ] && USER="anonymous"

  # Debug
  #echo "Trying rights ${RIGHT} on ${1}/${SHARE} for $USER $PASS"

  # User as string for the result
  USERSTR=$(getUserStr "$USER" "$PASS")

  case ${RIGHT} in
    # should be able to write
    ("w") [ $(canWriteSmb "${1}/${SHARE}" $USER $PASS) -eq 0 ] && RESULT="${RESULT}[${SHARE}${USERSTR}${RSEP}${RIGHT}]";;
    # by default check read but should not be able to write
    (*)
      [ $(canReadSmb "${1}/${SHARE}" $USER $PASS) -eq 0 ] && RESULT="${RESULT}[${SHARE}${USERSTR}${RSEP}r]";
      [ $(canWriteSmb "${1}/${SHARE}" $USER $PASS) -eq 1 ] && RESULT="${RESULT}[${SHARE}${USERSTR}${RSEP}w]";
    ;;
  esac

done

# Return 0 if all is ok else the string to display
[[ $RESULT = "" ]] && echo "0" || echo $RESULT
}

##############
# FUNCS UTIL #
##############

# ---
# Get the SMB shares of a server
# @param serverIP
# @return smb shares found
function getSmbShares()
{
echo $(
  smbclient -L $1 -g -N 2> /dev/null |
  awk -F'|' '$1 == "Disk" {print $2}' |
  while IFS= read -r SHARE
  do
          echo "${SHARE}"
  done
)
}

# ---
# Check if user can read in the SMB share
# @param serverIP/share
# @param user
# @param password
# @return true if can read
function canReadSmb()
{
smbclient "//$1" "$3" -U "$2" -c "dir" >/dev/null 2>&1 && echo 1 || echo 0
}

# ---
# Check if user can write in the SMB share
# @param serverIP/share
# @param user
# @param password
# @return true if can write
function canWriteSmb()
{
smbclient "//$1" "$3" -U "$2" -c "md -tmpfolderfroggtest-;rd -tmpfolderfroggtest-" >/dev/null 2>&1 && echo 1 || echo 0
}

# ---
# Get element at position after spliting a string
# @param string
# @param spliting char
# @param array position
# @return string at position splited
function getElementAt()
{
RESULT=""
# spliting the string
ELEMENTS=$(echo $1 | tr "$2" "\n")
i=1
for ELEMENT in $ELEMENTS
do
  # if position match return the string as result
  [ $i -eq $3 ] && RESULT=$ELEMENT
  ((i++))
done
echo $RESULT
}

# ---
# Return formated user as string for display the result without useless empty separator
# @param user
# @param pass
# @return formated |user:pass or |user if no pass or nothing if no user
function getUserStr()
{
RESULT=""
[ ! $1 = "" ] && RESULT="${SSEP}${1}" && [ ! $2 = "" ] && RESULT="${RESULT}${USEP}${2}"
echo $RESULT
}

########
# MAIN #
########

# Clean screen
#clear

case ${SMBACTION} in
  # command check share
  ("share")echo $(checkSmbShares "$SMBSERVER" "$SMBSHARES");;
  # command check right
  ("right")echo $(checkSmbRights "$SMBSERVER" "$SMBSHARES");;
  # command not set or invalid
  (*)echo "Error : command [${SMBACTION}] not found"
esac
