/bin/ls > y
/bin/cat < y | /usr/bin/sort | /usr/bin/uniq | /usr/bin/wc > y1
/bin/cat y1
/bin/rm y1
/bin/ls | /usr/bin/sort | /usr/bin/uniq | /usr/bin/wc
/bin/rm y