# File : make-report.sh
#
# Generates reports from my task data
#

#!/bin/bash

today=$(date +%Y-%m-%d)
/home/heiko/bin/timesheet.sh | ansi2html > /tmp/timesheet-all.html

cp /tmp/timesheet-all.html ~/timesheets/$today-all.html
cp /tmp/timesheet-all.html ~/timesheets/latest-all.html

rm /tmp/timesheet*.html
