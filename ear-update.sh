#!/bin/bash
#==============================================================================
# Copyright 2017 Cezary Tkaczyk
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#==============================================================================
# This script has been downloaded from:
#   https://github.com/ctkaczyk/ear-update
#==============================================================================

# {
#   "fileName":"ear-update.sh",
#   "description":[
#     "Bash script for manipulating files inside nested zip's (like jar's in ear)"  ],
#   "options":[
#   	{"var":"OPER", 	"letter":"t", "type":"ENUM", "enum":["UPDATE", "ADD", "DELETE", "GET"], "default":"GET", "required":"1", "desc":"operation type", "longDesc": "operation type."},
#     {"var":"EAR", 	"letter":"i", "type":"VAL", "enum":[], "default":"", "required":"2", "desc":"input ear", "longDesc": "path to ear to be manipulated"},
#     {"var":"XPATH",	"letter":"p", "type":"VAL", "enum":[], "default":"", "required":"3", "desc":"path", "longDesc": "path in the ear, e.g.: app-ejb.jar/META-INF/ejb-jar.xml"},
#     {"var":"SEDEXP","letter":"e", "type":"VAL", "enum":[], "default":"", "required":"0", "desc":"sed expresion", "longDesc": "in case of UPDATE, this is sed expression to be applied on file chosen by -p"},
#     {"var":"REGEXP","letter":"r", "type":"VAL", "enum":[], "default":"", "required":"0", "desc":"regexp", "longDesc": "regexp, which finds places in file chosen by -p to be replaced by file contents given by -f"},
#     {"var":"FILE",	"letter":"f", "type":"VAL", "enum":[], "default":"", "required":"0", "desc":"file", "longDesc": "if -p ADD, then this is a path to a file to be added, if -t UPDATE, then this is a path to a file used for replaceing matches of -r regexp"},
#     {"var":"OUTPUT", "letter":"o", "type":"VAL", "enum":[], "default":"", "required":"0", "desc":"output file", "longDesc": "output file name"}
#   ],
#   "examples":[
#   	"$0 -o ADD -i app.ear -p app-ejb.jar/META-INF/ejb-jar.xml -f ejb-jar.xml -vv",
#   	"$0 -o UPDATE -i app.ear -p app-ejb.jar/META-INF/ejb-jar.xml -r '<!-- SOME PLACEHOLDER -->' -f ejb-jar.xml.part -vv"
#   	],
#   "insertFileIntoFile":true,
#   "license":true,
#   "scriptSource":"https://github.com/ctkaczyk/ear-update",
#   "tmpDir":true
# }

#==============================================================================
set -e

usage() {
	echo "" 1>&2
	echo "Bash script for manipulating files inside nested zip's (like jar's in ear)" 1>&2
	echo "" 1>&2
	echo "Usage: $0 -t <UPDATE|ADD|DELETE|GEToperation type> -i <input ear> -p <path> [-e <sed expresion>] [-r <regexp>] [-f <file>] [-o <output file>] " 1>&2
	echo "" 1>&2
	echo "	-t		- operation type." 1>&2
	echo "	-i		- path to ear to be manipulated" 1>&2
	echo "	-p		- path in the ear, e.g.: app-ejb.jar/META-INF/ejb-jar.xml" 1>&2
	echo "	-e		- in case of UPDATE, this is sed expression to be applied on file chosen by -p" 1>&2
	echo "	-r		- regexp, which finds places in file chosen by -p to be replaced by file contents given by -f" 1>&2
	echo "	-f		- if -p ADD, then this is a path to a file to be added, if -t UPDATE, then this is a path to a file used for replaceing matches of -r regexp" 1>&2
	echo "	-o		- output file name" 1>&2
	echo "	-v		- verbose" 1>&2
	echo "	-l		- log file" 1>&2
	echo "" 1>&2
	echo "Examples: " 1>&2
	echo "" 1>&2
	echo "	$0 -o ADD -i app.ear -p app-ejb.jar/META-INF/ejb-jar.xml -f ejb-jar.xml -vv" 1>&2
	echo "" 1>&2
	echo "	$0 -o UPDATE -i app.ear -p app-ejb.jar/META-INF/ejb-jar.xml -r '<!-- SOME PLACEHOLDER -->' -f ejb-jar.xml.part -vv" 1>&2
	echo "" 1>&2
	exit 1
}

function logv () {
	if [[ $_V -gt 0 ]]; then
		if [ -z "$LOGFILE" ]; then
			echo "$_INDENT$@"
		else
			echo "[$(date "+%Y-%m-%d %H:%M:%S")]$_INDENT $@" >> $LOGFILE
		fi
	fi
}

function logvv () {
	if [[ $_V -gt 1 ]]; then
		if [ -z "$LOGFILE" ]; then
			echo "$_INDENT$@"
		else
			echo "[$(date "+%Y-%m-%d %H:%M:%S")]$_INDENT $@" >> $LOGFILE
		fi
	fi
}

function callDomestic {
	logvv $@
	(export _V && export LOGFILE && export _INDENT+="    " && $@)
}

function callExternal {
	logvv $@
	if [ -z "$LOGFILE" ]; then
		$@
	else
		$@ >> $LOGFILE 2>&1
	fi
}

INITIAL_CALL="$@"

#OPTS TO ENV VARIABLES
[[ -z $_V ]] && _V=0
OPER="GET"

while getopts ":vl:t:i:p:e:r:f:o:" ARG; do
	case "$ARG" in
		v)
			_V=$(($_V + 1))
			;;
		l)
			LOGFILE=$(pwd)/$OPTARG
			;;
		t)
			OPER=$OPTARG
			((OPER == "UPDATE" || OPER == "ADD" || OPER == "DELETE" || OPER == "GET")) || usage
			;;
		i)
			EAR=$OPTARG
			;;
		p)
			XPATH=$OPTARG
			;;
		e)
			SEDEXP=$OPTARG
			;;
		r)
			REGEXP=$OPTARG
			;;
		f)
			FILE=$OPTARG
			;;
		o)
			OUTPUT=$OPTARG
			;;
		*)
			usage
			;;
	esac
done
shift $((OPTIND-1))

#PARAMETERS VALIDATION
if [ -z "$OPER" ]; then
	usage
fi
if [ -z "$EAR" ]; then
	usage
fi
if [ -z "$XPATH" ]; then
	usage
fi



#PARAMETERS LOGOUT
logvv "================================================================================"
logvv "$0 $INITIAL_CALL"
logvv "================================================================================"
logvv OPER=$OPER
logvv EAR=$EAR
logvv XPATH=$XPATH
logvv SEDEXP=$SEDEXP
logvv REGEXP=$REGEXP
logvv FILE=$FILE
logvv OUTPUT=$OUTPUT
logvv LOGFILE=$LOGFILE

SCRIPT=$(realpath ${BASH_SOURCE[0]})
SCRIPTPATH=$(dirname $SCRIPT)
logvv SCRIPT=$SCRIPT
logvv SCRIPTPATH=$SCRIPTPATH
logvv "================================================================================"

function insertFileIntoFile {
	logvv "insertFileIntoFile" $@
	TEMPLATE_FILE=$1
	INSERTING_FILE=$2
	_REGEXP="$3"
	OUTPUT_FILE=$4
	logvv TEMPLATE_FILE=$TEMPLATE_FILE
	logvv INSERTING_FILE=$INSERTING_FILE
	logvv _REGEXP=$_REGEXP
	logvv OUTPUT_FILE=$OUTPUT_FILE

	TEMPLATE=$(<$TEMPLATE_FILE)
	INSERTING=$(<$INSERTING_FILE)

	logvv 'echo "${TEMPLATE//$_REGEXP/$INSERTING}" > ' $OUTPUT_FILE
	echo "${TEMPLATE//$_REGEXP/$INSERTING}" > $OUTPUT_FILE
	logvv
}

#Preparing temp directory
TMPDIR=$(mktemp -d)
function cleanup() {
  logvv "Cleaning $TMPDIR"
  test -n "$TMPDIR" && test -d "$TMPDIR" && rm -rf "$TMPDIR"
}

trap 'cleanup; exit 127' INT TERM ERR
#================================== SETUP FINISHED ====================================


if [ ! -z $FILE ]; then
  FILE=$(realpath $FILE)
  FILECONTENTS=$(<$FILE)
fi

#Parsing xpath
XPATH_DELIMITER='###'
XPATH_ELEMS=$(echo $XPATH | sed -e "s/\.\(jar\|war\|zip\|rar\|ear\|JAR\|WAR\|ZIP\|RAR\|EAR\)\//.\1$XPATH_DELIMITER/g" )
XPATH_ELEMS="root.ear$XPATH_DELIMITER$XPATH_ELEMS"
callExternal cp $EAR $TMPDIR/root.ear

logvv "Working in $TMPDIR"
callExternal cd $TMPDIR

function first() {
  echo $(echo $1 | sed -e "s/$XPATH_DELIMITER/\n/g" | head -n 1)
}

function last() {
  echo $(echo $1 | sed -e "s/$XPATH_DELIMITER/\n/g" | tail -n 1)
}

function sublist() {
  FROM=+$(( $2 + 1 ))
  TO="-$3"
  echo $1 | sed -e "s/$XPATH_DELIMITER/\n/g" | tail -n $FROM | head -n $TO
}


#logvv "first"
#first $XPATH_ELEMS
#logvv "last"
#last  $XPATH_ELEMS
#logvv "all"
#sublist "$XPATH_ELEMS" 0 0
#logvv "all but last"
#sublist $XPATH_ELEMS 0 1
#logvv "all but fist"
#sublist $XPATH_ELEMS 1 0
#logvv "all but first and last"
#sublist $XPATH_ELEMS 1 1

XPATH_ELEM_FIRST=$(first $XPATH_ELEMS)
XPATH_ELEM_LAST=$(last $XPATH_ELEMS)


# ===================== EXTRACTING =============================================
logv Extracting
SKIP=0;
if [ $OPER == "ADD" ] || [ $OPER == "DELETE" ]; then SKIP=1; fi
logvv SKIP=$SKIP
unset XPATH_ELEM_PREVIOUS
for XPATH_ELEM in $(sublist "$XPATH_ELEMS" 0 $SKIP); do
  if [ ! -z $XPATH_ELEM_PREVIOUS ]; then
    callExternal unzip -q -d . $XPATH_ELEM_PREVIOUS $XPATH_ELEM
  fi
  XPATH_ELEM_PREVIOUS=$XPATH_ELEM
done


# ======================== UPDATING ============================================
if [ $OPER == "UPDATE" ]; then
  logv "Updating $XPATH_ELEM"
  callExternal cp $XPATH_ELEM $XPATH_ELEM.tmp
  if [ ! -z "$SEDEXP" ]; then
    #REPLACING USING SED EXPRESSION
    logvv "cat $XPATH_ELEM.tmp | sed -e $SEDEXP > $XPATH_ELEM"
    cat $XPATH_ELEM.tmp | sed -e $SEDEXP > $XPATH_ELEM
  else
    #REPLACING USING REGEXP AND FILE CONTENTS
    if [ -z "$REGEXP" ] || [ -z "$FILE" ]; then
      usage
    fi
    insertFileIntoFile $XPATH_ELEM.tmp $FILE "$REGEXP" $XPATH_ELEM
  fi
elif [ $OPER == "ADD" ]; then
  callExternal mkdir -p $(dirname $XPATH_ELEM_LAST)
  callExternal cp $FILE $XPATH_ELEM_LAST
fi
#Deleting file
if [ $OPER == "DELETE" ]; then
  callExternal zip -qd $XPATH_ELEM $XPATH_ELEM_LAST
fi

# ===================== REPACKING ==============================================
if [ $OPER == "UPDATE" ] || [ $OPER == "ADD" ] || [ $OPER == "DELETE" ]; then
  SKIP=0
  [ $OPER == "DELETE" ] && SKIP=1
  logvv SKIP=$SKIP
  unset XPATH_ELEM_PREVIOUS
  for XPATH_ELEM in $(sublist "$XPATH_ELEMS" 0 $SKIP | tac); do
    if [ ! -z $XPATH_ELEM_PREVIOUS ]; then
      callExternal zip -qur $XPATH_ELEM $XPATH_ELEM_PREVIOUS
    fi
    XPATH_ELEM_PREVIOUS=$XPATH_ELEM
  done
fi


# ===================== FINAL RESPONSE =========================================
logvv cd -
cd - > /dev/null
case $OPER in
  UPDATE|ADD|DELETE)
    if [ -z $OUTPUT ]; then
      callExternal cp $TMPDIR/root.ear $EAR
    else
      callExternal cp $TMPDIR/root.ear $OUTPUT
    fi
    ;;
  GET)
    if [ -z $OUTPUT ]; then
      callExternal cp $TMPDIR/$XPATH_ELEM .
    else
      callExternal cp $TMPDIR/$XPATH_ELEM $OUTPUT
    fi
    ;;
  *)
    logv Wrong OPER=$OPER
    exit 127
    ;;
esac

cleanup
