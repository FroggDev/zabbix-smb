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
# ex: action=share share1,share2,share3
# ex: action=right share1|user1:pass1+r,share1|user2:pass2+w
SMBSHARES=$3

##########
# CONSTS #
##########
#Element separator
declare -r SEP=","
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
# Check if can check SMB rights
# @param serverIP
# @return 0/1
function canCheckSmbShares()
{
[[ $(smbclient -L $1 -g -N -U zabbix) == "session setup failed: NT_STATUS_ACCESS_DENIED" ]]  && return 1 || return 0
}

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

# get all SMB share sent by user separated by $SEP
SMBSHARES=$(echo $2 | tr "$SEP" "\n")

# For each SMB share test if exist in server SMB share list
while IFS= read -r SHARE; do
  #set share as lower case
  SHARE="[${SHARE,,}]"
  # Check if SMB share does not exist in SMB server shares
  if [[ ! " ${SMBSHARESFOUND} " =~ " ${SHARE} " ]]; then
    RESULT="${RESULT}${SHARE}"
  fi
done <<< ${SMBSHARES}

# Return nothing if all is ok, else the lis of share with trouble
echo $RESULT
}

# ---
# Get the SMB shares of a server
# @param serverIP
# @param shareList
# @return smb shares not found
function checkSmbRights()
{
RESULT=""

# get all SMB share sent by user separated by $SEP
SMBSHARES=$(echo $2 | tr "$SEP" "\n")

# For each SMB share test if exist in server SMB share list
while IFS= read -r SHAREINFO; do

  #DATAS = share|user:pass
  DATAS=$(getElementAt "$SHAREINFO" "$RSEP" 1)
  RIGHT=$(getElementAt "$SHAREINFO" "$RSEP" 2)
  #set right as lower case
  RIGHT=${RIGHT,,}

  SHARE=$(getElementAt "$DATAS" "$SSEP" 1)
  #set share as lower case
  SHARE=${SHARE,,}
  #USERS = user:pass
  USERS=$(getElementAt "$DATAS" "$SSEP" 2)

  USER=$(getElementAt "$USERS" "$USEP" 1)
  PASS=$(getElementAt "$USERS" "$USEP" 2)

  #Set USER=anonymous if no user set
  [ "$USER" = "" ] && USER="anonymous"

  # User as string for the result
  USERSTR=$(getUserStr "$USER" "$PASS")

  # Debug
  #echo "Trying rights ${RIGHT} on ${1}/${SHARE} for $USER $PASS"

  case ${RIGHT} in
    # should be able to write
    ("w") [ $(canWriteSmb "${1}" "${SHARE}" "$USER" "$PASS") -eq 0 ] && RESULT="${RESULT}[${SHARE}${USERSTR}${RSEP}${RIGHT}]";;
    # should not be able to read
    ("n") [ $(canReadSmb "${1}" "${SHARE}" "$USER" "$PASS") -eq 1 ] && RESULT="${RESULT}[${SHARE}${USERSTR}${RSEP}${RIGHT}]";;
    # by default check read but should not be able to write
    (*)
      [ $(canReadSmb "${1}" "${SHARE}" "$USER" "$PASS") -eq 0 ] && RESULT="${RESULT}[${SHARE}${USERSTR}${RSEP}r]";
      [ $(canWriteSmb "${1}" "${SHARE}" "$USER" "$PASS") -eq 1 ] && RESULT="${RESULT}[${SHARE}${USERSTR}${RSEP}w]";
    ;;
  esac

done <<< $SMBSHARES

# Return nothing if all is ok, else the lis of share with trouble
echo $RESULT
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
  smbclient -L $1 -g -N -U zabbix 2> /dev/null |
  awk -F'|' '$1 == "Disk" {print $2}' |
  while IFS= read -r SHARE
  do
    #set share as lower case
    echo "[${SHARE,,}]"
  done
)
}

# ---
# Check if user can read in the SMB share
# @param serverIP
# @param share
# @param user
# @param password
# @return true if can read
function canReadSmb()
{
# All before 1st /
SHARE="${2%%/*}"
# All after 1st /
FOLDER="${2#*/}/"

smbclient "//$1/$SHARE" "$4" -U "$3" -c "cd $FOLDER;dir" >/dev/null 2>&1 && echo 1 || echo 0
}

# ---
# Check if user can write in the SMB share
# @param serverIP
# @param share
# @param user
# @param password
# @return true if can write
function canWriteSmb()
{
# All before 1st /
SHARE="${2%%/*}"
# All after 1st /
FOLDER="${2#*/}/"

smbclient "//$1/$SHARE" "$4" -U "$3" -c "cd $FOLDER;md -tmpfolderfroggtest-;rd -tmpfolderfroggtest-" >/dev/null 2>&1 && echo 1 || echo 0
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
while IFS= read -r ELEMENT; do
  # if position match return the string as result
  [ $i -eq $3 ] && RESULT=$ELEMENT
  ((i++))
done <<< $ELEMENTS
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
  ("share")
  if canCheckSmbShares "$SMBSERVER";then
    echo $(checkSmbShares "$SMBSERVER" "$SMBSHARES")
  else
    echo "[ SMB rights error : NT_STATUS_ACCESS_DENIED ]"
  fi
  ;;
  # command check right
  ("right")echo $(checkSmbRights "$SMBSERVER" "$SMBSHARES");;
  # command not set or invalid
  (*)echo "Error : command [${SMBACTION}] not found"
esac
