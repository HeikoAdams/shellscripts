#!/bin/bash
# File : timesheet.sh
#
# This generates timesheet data for my fedora tasks only

source /home/heiko/.bashrc

phrase="1-weeks-ago"
#fmt="%m/%d/%Y"
fmt="%Y-%m-%d"
start=$(date +$fmt -d $phrase)
end=$(date +$fmt)
#filter="project.is:fedora"

echo " (generated at $(date))"
echo
echo " -- Tasks completed from $start to $end (back $phrase) -- "
/usr/bin/task work_report $filter end.after:$start

echo
echo " -- Upcoming tasks -- "
/usr/bin/task next $filter

echo
echo " -- Blocked tasks -- "
/usr/bin/task blocked $filter

echo
echo " -- Blocking tasks -- "
/usr/bin/task blocking $filter

echo
echo " -- Summary -- "
/usr/bin/task summary $filter

echo
echo " -- History -- "
/usr/bin/task history $filter
/usr/bin/task ghistory $filter
/usr/bin/task burndown.daily
/usr/bin/task burndown
