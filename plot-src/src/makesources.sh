#!/bin/sh

for file in *.xh; do  NEWFILE=`echo $file | sed 's/\.xh/\.h/g'`; echo $NEWFILE; ./xcpp.pl --export $NEWFILE < $file > $NEWFILE; done

for file in *.xc; do  NEWFILE=`echo $file | sed 's/\.xc/\.c/g'`; echo $NEWFILE; ./xcpp.pl --export $NEWFILE < $file > $NEWFILE; done
