#!/bin/bash
set -e
set -u

EAR=$1
XPATH=$2
REGEXP=$3

echo EAR=$EAR
echo XPATH=$XPATH
echo REGEXP=$REGEXP

#Parsing xpath
XPATH_DELIMITER='###'
XPATH_ELEMS=$(echo $XPATH | sed -e "s/\.\(jar\|war\|zip\|rar\|ear\|JAR\|WAR\|ZIP\|RAR\|EAR\)\//.\1$XPATH_DELIMITER/g" )
XPATH_ELEMS_COUNT=$(echo $XPATH_ELEMS | sed -e "s/$XPATH_DELIMITER/\n/g" | wc -l)


#Preparing temp directory
TMPDIR=$(/bin/mktemp -d)
cleanup() {
    test -n "$TMPDIR" && test -d "$TMPDIR" && rm -rf "$TMPDIR"
}

trap 'cleanup; exit 127' INT TERM

cp $EAR $TMPDIR/root.ear

echo "Working in $TMPDIR"
cd $TMPDIR

#Extracting
XPATH_ELEM=root.ear
for i in $(echo $XPATH_ELEMS | sed -e "s/$XPATH_DELIMITER/\n/g"); do
  echo jar xf $XPATH_ELEM $i
  jar xf $XPATH_ELEM $i
  XPATH_ELEM=$i
done

#Changing file
echo cp $XPATH_ELEM $XPATH_ELEM.tmp
cp $XPATH_ELEM $XPATH_ELEM.tmp
echo "cat $XPATH_ELEM.tmp | sed -e $REGEXP > $XPATH_ELEM"
cat $XPATH_ELEM.tmp | sed -e $REGEXP > $XPATH_ELEM

#Repacking
for i in $(echo $XPATH_ELEMS | sed -e "s/$XPATH_DELIMITER/\n/g" | tac | tail -n +2); do
  echo jar uf $i $XPATH_ELEM
  jar uf $i $XPATH_ELEM
  XPATH_ELEM=$i
done

echo  jar uf root.ear $XPATH_ELEM
jar uf root.ear $XPATH_ELEM

cd -
cp $TMPDIR/root.ear $EAR

exit 123

if [[ $XPATH =~ "jar" ]]; then
  ZIP=root.ear
  XPATH_ELEMS=$(echo $XPATH | sed -e "s/\.jar\//.jar\n/g" )
#  XPATH_ELEMS=$(echo -e "$XPATH_ELEMS\n")
  echo "Elems in a path: $XPATH_ELEMS"
  for i in $XPATH_ELEMS
  do
    echo jar xf $ZIP $i
    jar xf $ZIP $i
    ZIP=$i
  done

  echo $ZIP
  #XPATH_LAST=$(echo $XPATH_ELEMS | tail -1 )
  XPATH_LAST=$ZIP

  cp $XPATH_LAST $XPATH_LAST.tmp
  cat $XPATH_LAST.tmp | sed -e $REGEXP > $XPATH_LAST

  for i in $(echo $XPATH | sed -e "s/\.jar\//.jar\n/g" | grep . | tac); do
    if [[ ! "$XPATH_LAST" == "$i" ]]
    then
      echo jar uf $i $ZIP
      jar uf $i $ZIP
    fi
    echo     ZIP=$i
    ZIP=$i
  done
  echo   jar uf root.ear $ZIP
  jar uf root.ear $ZIP

else
  echo asdf
fi

cd -
cp $TMPDIR/root.ear $EAR
