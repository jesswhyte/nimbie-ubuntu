#!/bin/bash -xe
# jess whyte, @jesswhyte Aug 2018

## adaptation of nimbie.sh now with more logging 

# usage example : bash nimbie-utl.sh /path/to/where/you/want/to/store/isofiles | tee -a yourlogfile.log

# you have to request and download linux SDK from Acronova
# make /64/autoloader executable

## jess notes: continue points = not iso, blank blocksize or blank blockcount or dd status != 0
## jess notes: autoloader status on LOAD, +s14 = no disk there [DONE WITH PILE], +s07 = OK, + s10 = drive closed, + s12 = disk already in 


autoloader="sudo /usr/local/bin/Linux2017Q1_General/64/autoloader" # path to executable on local machine 

cdcheck(){
	# this function adapted from cd.close - by https://superuser.com/users/464868/allan 
	CDROM=/dev/sr1
	TRIES="1 2 3 4"
	INTERVAL=5
	MOUNT=0

	TOKENS=( $TRIES )
	STOP=${TOKENS[-1]}

	for i in $TRIES; do
	echo close: ATTEMPT $i of $STOP
	
	output=`file -s $CDROM`
	
	echo OUTPUT $output
	
	if [[ "$output" != "/dev/sr1: writable, no read permission" ]]; then #to do: think about ways to do this better, e.g. another method w/ clearer status exits
		MOUNT=1
		break
	fi
	
	if [ $i -eq $STOP ]; then
		break
	fi
	
	echo sleep: $INTERVAL SECONDS...
	sleep $INTERVAL
	done

	if [ $MOUNT -eq 1 ]; then
		echo final: $CDROM
		printf "final: LABEL "
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

s_status="+S07" ## set starting s-status
 
while [ "s_status" != "+S14" ]; do
	eject /dev/sr1 ## eject the drive tray

	output=`$autoloader LOAD` ## load a disk
	s_status=`echo $output | grep -oP "\+S\d\d"` # get the S-code from the autoloader response, autoloader S14 = no more disks
	
	if [[ $s_status == "+S14" ]]; then
	  echo "Done!"
	  exit 0
	fi
	
	eject -t /dev/sr1 ## close the drive tray

	cdcheck ## check cd is loaded

	#cdinfo=`isoinfo -d -i /dev/sr1` # get isoinfo
	
	## Set Volume name as variable
	volume=`isoinfo -d -i /dev/sr1  | grep "^Volume id:" | cut -d ":" -f 2` # gets volume name
	volume=`echo $volume | tr -d [:punct:] | sed 's/\s/\_/g'` # strips out punct and converts spaces to _
	time=`date +%Y%m%d_%H%M%S` # make a time stamp
	
	path=`realpath $1` # assumes you gave a path as an argument
	echo $path/$time-$volume.iso # assemble file name for destination .iso, echo for error checking
	
	echo $time >> $path/$time-$volume.log
	
		# Display cd Info
	echo "---------------------CD INFO-----------------------"  
	isoinfo -d -i /dev/sr1 | tee -a $path/$time-$volume.log						
	echo "----------------------------------------------------"
	
	## Get Block size of CD  ##  NOTE: IF the CD is NOT AN ISO, IT IS REJECTED! 
	
	blocksize=`isoinfo -d -i /dev/sr1 | grep "^Logical block size is:" | cut -d ":" -f 2 | tr -d '[:space:]'` # gets blocksize from isoinfo output, if I do as variable, the string is too tricky
	if test "$blocksize" = ""; then
			echo catdevice FATAL ERROR: Blank blocksize >&2 
			reject
			continue
	fi

	## Get Block count of CD
	blockcount=`isoinfo -d -i /dev/sr1  | grep "^Volume size is:" | cut -d ":" -f 2 | tr -d '[:space:]'` # gets blockcount from isoinfo output
	if test "$blockcount" = ""; then
			echo catdevice FATAL ERROR: Blank blockcount >&2 
			reject
			continue
	fi

	echo ""
	echo "blocksize of CD is: "$blocksize
	echo "blockcount of CD is: "$blockcount
	echo ""

	## Run dd on disc
	
	dd if=/dev/sr1 of=$path/$time-$volume.iso bs=$blocksize count=$blockcount status=progress | tee -a $path/$time-$volume.log # runs dd using found bs and bc, appends output to log
	status=$? 

	if [ $status != 0 ]; then #not yet tested
		reject
		continue
	fi

	eject /dev/sr1 ## eject the drive tray
	
	$autoloader PICK ## pick up the disk

	eject -t /dev/sr1 ##close the drive tray
        sleep 5
	$autoloader UNLOAD 	##unload the disk
        sleep 5
done

