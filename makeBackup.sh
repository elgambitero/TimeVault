# ----------------------------------------------------------------------
# gvJaime's time capsule-like backup script
# ----------------------------------------------------------------------
# Based on Mike Rubel's scripts in
# www.mikerubel.org/computers/rsync_snapshots
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# Script Explanation
# ----------------------------------------------------------------------
#
# Scripts that makes incremental backups "a la Time Machine".
# Incremental, with timestamped snapshots.
#
# When executed, it creates a folder whose name will be the date of the
# snapshot. e.g: a the 4th of May of 2017, at 16:20, will generate
# a folder called 20170504_1620. And inside, your contents.
#
# BUT WAIT! there's more!
#
# The unchanged files are not loaded again. They are hardlinked to the
# previous snapshot, so the snapshot will look the same, but only the
# changed files will be there.
#
# ----------------------------------------------------------------------
# NOTES
#
# OPTIMIZE BACKUPS BY HARDLINKING IDENTICAL FILES
# ----------------------------------------------------------------------

unset PATH

#-----------------------------------------------------------------------
# ------------- system commands used by this script -------------------
#-----------------------------------------------------------------------

PWD=/bin/pwd;
DF=/bin/df;
ID=/usr/bin/id;
ECHO=/bin/echo;
MOUNT=/bin/mount;
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;
LS=/bin/ls;
TAIL=/bin/tail;
SORT=/bin/sort;
DIRNAME=/bin/dirname;
SED=/bin/sed;
DATE=/bin/date;
RSYNC=/usr/bin/rsync;
CHMOD=/bin/chmod;
MKDIR=/bin/mkdir;
FIND=/bin/find;
XARGS=/bin/xargs;
SHA512=/bin/sha512sum;
TR=/bin/tr
GREP=/bin/grep;
CUT=/bin/cut;
SED=/bin/sed;
CLEAR=/bin/clear;

#-----------------------------------------------------------------------
# ------------- filename pattern for backup folders -------------------
#-----------------------------------------------------------------------

backupPattern="[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9]"

#-----------------------------------------------------------------------
# ------------- file locations ----------------------------------------
#-----------------------------------------------------------------------

# This script must be stored on the root of the backup device.
# It also considers that the device is mounted with rw.

SOURCE_FOLDER="$1"; # INSERT THE FOLDER YOU WANT TO BACKUP HERE
BACKUP_FOLDER="$2";
EXCLUDES=$BACKUP_FOLDER/backup_exclude;
FINDINDEX=1;


#-----------------------------------------------------------------------
# ------------ The Script ---------------------------------------------
#-----------------------------------------------------------------------


# -------------- Previous Checks ---------------------------------------

function prevCheck {
	# Make sure we're running as root
	if (( `$ID -u` != 0 )); then
		{ $ECHO "This scripts must be run as root.  Exiting..."; exit; }
	fi

	# Check if the user has specified the folder to backup
	if [ -z "$1" ]; then
	    $ECHO "You must specify the folder to backup";
	    $ECHO "Syntax is: makeBackup.sh <source folder> <destination folder>"
	    exit;
	fi

	# Check if the user has specified the folder to backup
	if [ -z "$2" ]; then
	    $ECHO "You must specify the folder to make the backup into";
	    $ECHO "Syntax is: makeBackup.sh <source folder> <destination folder>"
	    exit;
	fi

	# Check if the destination directory is contained in a ext4 filesystem
	if [ "$($DF -T "$BACKUP_FOLDER" | $GREP "ext4")" == "" ]; then
	    $ECHO "The destination folder must be contained into a ext4 filesystem";
	    exit;
	fi

	# Make sure the source volume is mounted!!!! TODO

	if [ ! -d $SOURCE_FOLDER ]; then
		{ $ECHO "Source directory doesn't exist or it is not mounted"; exit; }
	fi

	# Create a excludes file in case there is none

	if [ ! -e $EXCLUDES ]; then
		{ $ECHO "backup_excludes file not found in $EXCLUDES, creating...";
		$TOUCH $EXCLUDES; }
	fi
}

#--------------------Functions--------------------------------------------

function startUp {

    PRV="$($FIND "$BACKUP_FOLDER" -name "$backupPattern" | $SORT | $TAIL -n -$FINDINDEX)";
    if [ "$PRV" = "" ]; then
	PREVIOUS_BACKUP=$PRV;
	PREVIOUS_CONTENTS=$PRV;
	OLD_LOCATIONS="";
	$ECHO "No previous backup found. Assuming this is your first backup.";
	NEXT_BACKUP=$BACKUP_FOLDER/$($DATE +%Y%m%d_%H%M);
	NEXT_CONTENTS=$NEXT_BACKUP/Contents;
	NEW_LOCATIONS=$BACKUP_FOLDER/fileindex.txt;	
	this_is_the_first=true;
    else
	PREVIOUS_BACKUP=$PRV;
	PREVIOUS_CONTENTS=$PREVIOUS_BACKUP/Contents;
	OLD_LOCATIONS=$PREVIOUS_BACKUP/fileindex.txt;

	NEXT_BACKUP=$BACKUP_FOLDER/$($DATE +%Y%m%d_%H%M);
	NEXT_CONTENTS=$NEXT_BACKUP/Contents;
	NEW_LOCATIONS=$BACKUP_FOLDER/fileindex.txt;
	
	if [ ! -e "$PREVIOUS_BACKUP/fileindex.txt" ]; then
	    $ECHO "Previous backup $PREVIOUS_BACKUP wasn't performed. Marking as error...";
	    $ECHO "You are free to delete that snapshot when you feel safe";
	    $MV "$PREVIOUS_BACKUP" "$BACKUP_FOLDER"/"ERROR""${PRV#$($ECHO "$BACKUP_FOLDER")}";
	    FINDINDEX=$(($FINDINDEX + 1));
	    startUp;
	else
	    PREVIOUS_BACKUP=$PRV;
	    PREVIOUS_CONTENTS=$PREVIOUS_BACKUP/Contents;
	    OLD_LOCATIONS=$PREVIOUS_BACKUP/fileindex.txt;
	fi
	this_is_the_first=false;
    fi 
}


function getShaSums {
    $ECHO "Get SHA512sums for the new directory...";
    # Search all the files in the new tree, get their SHA512 sums,
    # and get them into the NEW_LOCATIONS file.
    $FIND "$SOURCE_FOLDER" -type f -exec $ECHO -n '"{}" ' \; | $TR '\n' ' ' | $XARGS $SHA512 | $GREP -vf $EXCLUDES > $NEW_LOCATIONS;
}

function transferTree {

    if [ "$this_is_the_first" = true ]; then
	$ECHO "This is your first backup, you don't have a previous tree to transfer from."
	return;
    fi
    
    if [ ! -e "$NEW_LOCATIONS" ]; then
	$ECHO "You have to generate the SHA512 sum filelist first!"
        return;
    fi

    # Make hardlinked copy of previous backup.

    $ECHO "Making hardlinked copy of previous backup into $NEXT_CONTENTS";
	
    $MKDIR -p $NEXT_CONTENTS
    $CP -al "$PREVIOUS_CONTENTS/"* "$NEXT_CONTENTS/";
    
}

function updateTree {

    if [ "$this_is_the_first" = true ]; then
	return;
    fi

	if [ ! -e "$NEXT_CONTENTS" ]; then
	    $ECHO "You have to transfer the tree first!"
	    return;
	fi

	# If some file has been renamed, rename the hardlink to the new location
	# before performing rsync.

	$ECHO "Perform a search of each of the sha sums, to detect renames"
	$ECHO "And build the new tree"

	while read p; do
	    
	    SHA=$($CUT -f1 -d " " <<< $p); # SHA contains the SHA signature of current new file.

	    # NEW_LOC contains a list of new locations for this file.
	    NEW_LOC=${p#$($ECHO $SHA"  ")}; # NEW_LOC contains the location of the file.

	    # OLD_LOC contains a list of old locations for this file.
	    OLD_LOC=$($ECHO "$($GREP "$SHA" $OLD_LOCATIONS)"); 

	    # $ECHO "Reading file $SHA";
	    # $ECHO "OLD_LOC is .$OLD_LOC.";
	    
	    # If this file doesn't exist in the old list, it is a new file, so moving on.
	    if [ -z "$OLD_LOC" ]; then
		continue;
	    fi

	    # Look for the new relative location into the old locations.
	    # If you find that relative location, continue to the next file.
	    if  $ECHO "$OLD_LOC" | $GREP -q "$NEW_LOC"
	    then
		continue;
	    fi
	    
	    # Iterate through the lines of old locations.
	    # Make a hard link to the new destination
	    # If the link is already done, it will overwrite, but this won't matter
	    # Because it is the exact same file.
	    while read -r line; do
		#$ECHO "$line";
		PREVIOUS_LOC=${line#$($ECHO $SHA"  ")};
		$MKDIR -p "$NEXT_CONTENTS/$($DIRNAME "$NEW_LOC")";
	        $CP -al "$PREVIOUS_CONTENTS/${PREVIOUS_LOC#$($ECHO "./")}" "$NEXT_CONTENTS/${NEW_LOC#$($ECHO "./")}";
		# $ECHO "Moving $PREVIOUS_CONTENTS/${PREVIOUS_LOC#$($ECHO "./")} to $NEXT_CONTENTS/${NEW_LOC#$($ECHO "./")}"
	    done <<< "$OLD_LOC"
	done <$NEW_LOCATIONS

    
}

function doTheBackup {

	# Somehow check the if there is a backup waiting to be done.
	
	# Sync the folders.

	if [ "$this_is_the_first" = true ]; then
		$MKDIR -p $NEXT_CONTENTS;
	fi
	
	$ECHO "Calling rsync..."

	$RSYNC								\
	    -va --delete --delete-excluded				\
	    --no-inc-recursive --exclude-from="$EXCLUDES"		\
	    $SOURCE_FOLDER/ $NEXT_CONTENTS/;

	# Update the "Last modified" tag.

	$TOUCH $NEXT_BACKUP;

	# Move the new file list into the new backup.

	$MV $NEW_LOCATIONS $NEXT_BACKUP/fileindex.txt;

	# Echo an end message because why not.

	$ECHO "$BACKUP_FOLDER was backed up into $NEXT_BACKUP"

    
}


# -------------Main Menu------------------------------------------------


function mainMenu {
	# $CLEAR # Clear terminal screen.

	PS3="gvJaime's back up utility. Select an option to continue:";

	OPTIONS="\"Generate sha512 sums for backup\" \"Transfer backup tree\" \"Make backup\" \"Perform a complete cycle\" \"Perform cycle without checksums\" \"Quit\"";
	eval set $OPTIONS;
	select opt in "$@"; do
		case "$opt" in
		"Generate sha512 sums for backup")
			getShaSums;
			;;
		"Transfer backup tree")
		    transferTree;
		    updateTree;
			;;
		"Quit")
			$ECHO "Exiting..."
			exit;
			;;
		"Make backup")
			doTheBackup;
			;;
		"Perform a complete cycle")
			getShaSums;
			transferTree;
			updateTree;
			doTheBackup;
			exit;
			;;
		"Perform cycle without checksums")
			transferTree;
			updateTree;
			doTheBackup;
			;;
		*)
			$ECHO "Bad option";
		esac
	done
}

prevCheck $1 $2;
startUp;
mainMenu;
