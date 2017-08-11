#!/bin/sh

ASSERTLIB=assert.alib
DUT=../../lib/lib.awk

# if we did not have any parameters passed in
if [ -z "$*" ] ; then
    TESTS=`ls -1 *.awk `
else
    TESTS="$@"
fi
for f in $TESTS ; do
    printf "Running Test %s..." $f
    RESULT=$(awk -f $DUT -f $ASSERTLIB -f $f  < /dev/null)
    if [ "$?" == 0 ] ; then
	echo OK
    else
	echo FAIL
	echo $RESULT
    fi
done
