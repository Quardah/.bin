#!/bin/sh

vol=`amixer sget Master | grep "Front Right:" | awk '{ print "Vol : " $5 " " $6 }'`

echo $vol

exit 0
