#!/bin/sh

# usage: create_dmg.sh image "Volume"

# if a previous copy of the image exists, remove it
rm -f build/$1.dmg

# create the image. 
hdiutil create build/$1.dmg -ov -size 02m -fs HFS+ -volname "$2"

# mount the image and store the device name into dev_handle
dev_handle=`hdid build/$1.dmg | grep Apple_HFS | perl -e '\$_=<>; /^\\/dev\\/(disk.)/; print \$1'`

# copy the software onto the disk
ditto -rsrc "RELEASENOTES.txt" "/Volumes/$2/"
ditto -rsrc "LICENSE" "/Volumes/$2/"
ditto -rsrc "build/Release" "/Volumes/$2/"
ditto -rsrc "sampledata/" "/Volumes/$2/sampledata"

# unmount the volume
hdiutil detach $dev_handle

# compress the image
hdiutil convert build/$1.dmg -format UDZO -o build/$1.udzo.dmg

# remove the uncompressed image
rm -f build/$1.dmg

# move the compressed image to take its place
mv build/$1.udzo.dmg build/$1.dmg
