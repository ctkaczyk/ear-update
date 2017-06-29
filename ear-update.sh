#!/bin/bash
set -e



usage() {
  echo "" 1>&2
  echo "Bash script for manipulating files inside nested zip's (like jar's in ear)" 1>&2
  echo "" 1>&2
  echo "Usage: $0 [-o <UPDATE|ADD|DELETE|GET>] [-i <ear>] [-p <path in ear>] [-e <sed expression to be executed on file>] [-r <regexp>] [-f <file>] [-v]" 1>&2
  echo "" 1>&2
  exit 1
}

function logv () {
    if [[ $_V -gt 0 ]]; then
        echo "$@"
    fi
}

function logvv () {
    if [[ $_V -gt 1 ]]; then
        echo "$@"
    fi
}

_V=0
while getopts ":vi:o:p:e:r:f:" x; do
    case "${x}" in
        v)
            _V=$(($_V + 1))
            ;;
        o)
            OPER=${OPTARG}
            (($OPER == "UPDATE" || $OPER == "ADD" || $OPER == "DELETE")) || usage
            ;;
        i)
            EAR=${OPTARG}
            ;;
        p)
            XPATH=${OPTARG}
            ;;
        e)
            SEDEXP=${OPTARG}
            ;;
        r)
            REGEXP=${OPTARG}
            ;;
        f)
            FILECONTENTS=$(<$OPTARG)
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$OPER" ] || [ -z "$EAR" ] || [ -z "$XPATH" ] || [ -z "$REGEXP$SEDEXP" ]; then
    usage
fi

logvv OPER=$OPER
logvv EAR=$EAR
logvv XPATH=$XPATH
logvv SEDEXP=$SEDEXP
logvv REGEXP=$REGEXP
logvv FILECONTENTS=$FILECONTENTS

#Parsing xpath
XPATH_DELIMITER='###'
XPATH_ELEMS=$(echo $XPATH | sed -e "s/\.\(jar\|war\|zip\|rar\|ear\|JAR\|WAR\|ZIP\|RAR\|EAR\)\//.\1$XPATH_DELIMITER/g" )
XPATH_ELEMS_COUNT=$(echo $XPATH_ELEMS | sed -e "s/$XPATH_DELIMITER/\n/g" | wc -l)


#Preparing temp directory
TMPDIR=$(mktemp -d)
cleanup() {
  logvv "Cleaning $TMPDIR"
  test -n "$TMPDIR" && test -d "$TMPDIR" && rm -rf "$TMPDIR"
}

trap 'cleanup; exit 127' INT TERM

cp $EAR $TMPDIR/root.ear

logvv "Working in $TMPDIR"
cd $TMPDIR

#Extracting
XPATH_ELEM=root.ear
for i in $(echo $XPATH_ELEMS | sed -e "s/$XPATH_DELIMITER/\n/g"); do
  logv jar xf $XPATH_ELEM $i
  jar xf $XPATH_ELEM $i
  XPATH_ELEM=$i
done

#Changing file
logv "Updating $XPATH_ELEM"
logv cp $XPATH_ELEM $XPATH_ELEM.tmp
cp $XPATH_ELEM $XPATH_ELEM.tmp
if [ ! -z "$SEDEXP" ]; then
  #REPLACING USING SED EXPRESSION
  logv "cat $XPATH_ELEM.tmp | sed -e $SEDEXP > $XPATH_ELEM"
  cat $XPATH_ELEM.tmp | sed -e $SEDEXP > $XPATH_ELEM
else
  #REPLACING USING REGEXP AND FILE CONTENTS
  if [ -z "$REGEXP" ] || [ -z "$FILECONTENTS" ]; then
    usage
  fi
  XPATH_ELEM_CONTENTS=$(<$XPATH_ELEM.tmp)
  echo "${XPATH_ELEM_CONTENTS//$REGEXP/$FILECONTENTS}" > $XPATH_ELEM
fi

#Repacking
for i in $(echo $XPATH_ELEMS | sed -e "s/$XPATH_DELIMITER/\n/g" | tac | tail -n +2); do
  logv jar uf $i $XPATH_ELEM
  jar uf $i $XPATH_ELEM
  XPATH_ELEM=$i
done

logv  jar uf root.ear $XPATH_ELEM
jar uf root.ear $XPATH_ELEM

logvv cd -
cd - > /dev/null
cp $TMPDIR/root.ear $EAR
cleanup
