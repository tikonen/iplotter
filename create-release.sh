#!/bin/sh -x

VERSTR=1.0.3-b2

./create-dmg.sh "iPlotter-$VERSTR" iPlotter
tar --exclude=.svn --exclude=build '--exclude=*~*' -czvf ../iPlotter-src-$VERSTR.tar.gz .


