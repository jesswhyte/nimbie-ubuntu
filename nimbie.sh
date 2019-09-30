#!/bin/bash

# NOTE: THIS IS A LOCALIZED VERSION - CONTAINS REFERENCE TO AUTOLOADER THAT DOES NOT MATCH DEFAULT INSTALL

# jess whyte, @jesswhyte Aug 2018 

# usage example : bash nimbie.sh /media/storage/Nimbie_ISOs/

# you have to request and download linux SDK from Acronova
# make /64/autoloader executable

## jess notes: continue points = not iso, blank blocksize or blank blockcount or dd status != 0
## jess notes: autoloader status on LOAD, +s14 = no disk there [DONE WITH PILE], +s07 = OK, + s10 = drive closed, + s12 = disk already in 

gsettings set org.gnome.desktop.media-handling automount-open false 
##if you don't want nautilus to launch a window every time it mounts a disk

autoloader="sudo /usr/local/bin/autoloader" # path to executable on local machine - not needed if added to path, etc.

cdcheck(){
	# this function adapted from cd.close - by https://superuser.com/users/464868/allan 
	CDROM=/dev/sr1
	TRIES="1 2 3 4"
	INTERVAL=5
	MOUNT=0

	TOKENS=( $TRIES )
	STOP=${TOKENS[-1]}

	for i in $TRIES; do
	#echo close: ATTEMPT $i of $STOP
	
	output=`file -s $CDROM`
	
	#echo OUTPUT $output
	
	if [[ "$output" != "/dev/sr1: writable, no read permission" ]]; then #to do: think about ways to do this better, e.g. another method w/ clearer status exits
		MOUNT=1
		break
	fi
	
	if [ $i -eq $STOP ]; then
		break
	fi
	
	#echo sleep: $INTERVAL SECONDS...
	sleep $INTERVAL
	done

	if [ $MOUNT -eq 1 ]; then
		#echo final: $CDROM
		#printf "final: LABEL "
		volname $CDROM
	else
		echo final: NO MEDIUM DETECTED
		reject
		break
	fi
}

reject(){
	echo REJECTING... 
	eject /dev/sr1 && $autoloader PICK && eject -t /dev/sr1 && $autoloader REJECT
}

$autoloader INIT ## initialize the nimbie

s_status="+S07" ## set starting s_status
 
while [ "s_status" != "+S14" ]; do

	eject /dev/sr1 ## eject the drive tray

	output=`$autoloader LOAD` ## load a disk
	
	s_status=`echo $output | grep -oP "\+S\d\d"` # get the S-code from the $autoloader response, $autoloader S14 = no more disks
	
	if [[ $s_status == "+S14" ]]; then
	  echo "Done all the disks!"
	  exit 0
	fi
	
	eject -t /dev/sr1 ## close the drive tray

	cdcheck ## check cd is loaded

	#cdinfo=`isoinfo -d -i /dev/sr1` # get isoinfo
	
	## Set Volume name as variable
	volume=`isoinfo -d -i /dev/sr1  | grep "^Volume id:" | cut -d ":" -f 2` # gets volume name
	volume=`echo $volume | tr -d [:punct:] | sed 's/\s/\_/g'` # strips out punct and converts spaces to _	
	#if volume name is null...
        if [[ -z "$volume" ]]; then
          volume="null-volume-$time"
        fi

	time=`date +%Y%m%d_%H%M%S` # make a time stamp
	
	path=`realpath $1` # assumes you gave a path as an argument
	echo $path/$volume.iso # assemble file name for destination .iso, echo for error checking
	
			# Display cd Info
	echo "---------------------CD INFO-----------------------"  
	isoinfo -d -i /dev/sr1 						
	echo "----------------------------------------------------"
	
	## Get Block size of CD  ##  NOTE: IF the CD is NOT AN ISO, IT IS REJECTED! 
	
	blocksize=`isoinfo -d -i /dev/sr1 | grep "^Logical block size is:" | cut -d ":" -f 2 | tr -d '[:space:]'` # gets blocksize from isoinfo output, if I do as variable, the string is too tricky
	if test "$blocksize" = ""; then
			echo catdevice FATAL ERROR: Blank blocksize. Rejecting disk. >&2 
			reject
			continue
	fi

	## Get Block count of CD
	blockcount=`isoinfo -d -i /dev/sr1  | grep "^Volume size is:" | cut -d ":" -f 2 | tr -d '[:space:]'` # gets blockcount from isoinfo output
	if test "$blockcount" = ""; then
			echo catdevice FATAL ERROR: Blank blockcount. Rejecting disk.  >&2 
			reject
			continue
	fi

	echo ""
	echo "blocksize of CD is: "$blocksize
	echo "blockcount of CD is: "$blockcount
	echo ""

	## Run dd on disc
	
	dd if=/dev/sr1 of=$path/$volume.iso bs=$blocksize count=$blockcount status=progress 
	status=$? 

	if [ $status != 0 ]; then #not yet tested
		reject
		continue
	fi
	
	chgrp floppy $path/$volume.iso #change the owner group of iso to floppy
	
	sleep 5 
	
	eject /dev/sr1 ## eject the drive tray
	
	outputpick=`$autoloader PICK` ## pick up the disk
	s_statuspick=`echo $outputpick | grep -oP "\+S\d\d"` # get the S-code from the $autoloader response, $autoloader S10 = drive closed, can't pick, sometimes there is an issue here
	
	if [[ $s_statuspick == "+S10" ]]; then
	  echo "Drive is still closed, not ejecting...EXITING"
	  exit 0	 
	fi
		
	
	sleep 5

	eject -t /dev/sr1 ##close the drive tray
	
        sleep 5
        
	$autoloader UNLOAD 	##unload the disk
	
        sleep 5
done

