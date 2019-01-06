# TimeVault

## Overview

TimeVault is a script written in bash, that makes incremental backups "a la Apple's Time Machine", but for linux: It generates timestamped snapshots that only store changed files, saving space.

When executed, it creates a folder whose name will be the date of the snapshot. e.g: the 4th of May of 2017, at 16:20, will generate a folder called 20170504_1620. And inside, your contents.

Simplified usage:

```
./timeVault.sh source_folder backup_folder
```

and then hit the 4th option "Perform a Complete Cycle", and let it sit for a long while.

The backup is stored with this folder structure:

```
/backup_folder
-20170101_0438
	-Contents
    	-...
    -fileindex.txt
-20170504_1620
	-Contents
    	-...
    -fileindex.txt
...
-backup_excludes
```

The files are stored inside the "Contents" folder.

### Requirements

* The destination folder must be contained in a volume formated in the EXT4 filesystem.
* The destination folder must be writable by the user.

## Disclaimer

**Use at your own risk. I take no responsibility from any loss or data, or any kind of damage or negative consequence derived from the use of this script.** That being said, I hope this script is useful to back up your stuff.

## Description

TimeVault is based on the scripts presented in [this article by Mike Rubel](http://www.mikerubel.org/computers/rsync_snapshots/). These make use of the ```rsync``` and ```cp``` commands to make copies of the same folder, with the unchanged files linked to the previous backup.

The author makes a good description about the mechanics involved in the process. ```cp -al``` is used to make a hardlinked (more on that later) copy of the old tree, and ```rsync --delete``` to add the new files, and delete the ones that no longer exist the source folder.

However, this approach doesn't take in account those files that are simply moved, so ```rsync``` will just erase them and create them somewhere else without really noticing that they are the same file; therefore taking new space in the process.

For this, TimeVault adds a previous stage to the process, in which a checksum is calculated for every file in the source folder, so identical files are detected and not stored again.
* A consequence of this is that if there are identical files on the source folder, those are detected and stored only once in the backup; potentially resulting in the backup being smaller than the original folder in some cases.


### About hard links

Hard links are a feature notably used by this script, that are a consequence of the way the EXT4 filesystem stores files.

In EXT4, the content of a file is store in something called "inode". Inodes hold the content of all the files on the disk, and the files that you see in the file explorer are just pointers to those inodes. One inode can be pointed by multiple files, creating the illusion of having many instances of them, but the content is stored once. Those files that point to the same inode are said to be "hardlinked".

TimeVault does just that. When it detects that a file hasn't changed, it just makes a hard link to the previous version of the file, resulting in no additional disk space use.

### Workflow

1. Calculate checksums of all the files, and store them in a file.
2. If it is not the first backup you do:
	1. Transfer the old file tree from the previous backup, by making hard linked copy of it. It uses ```cp -al```
	2. Modify the transferred tree until it looks like the new one, comparing the checksum file of the previous backup to the checksum file of the new; detecting renames and moves.
3. Execute ```rsync --delete```, to transfer the new files, and delete those that no longer exist.
4. Name the backup folder with the timestamp, store the checksum file there, and protect the folder against writing.

## Reasonably askable questions (RAQ)

* Why does it take so long?
	* Making a checksum of one and every file of the disk is like just reading the whole disk and looking at the differences. This seems like bruteforcing, but as a first approach it seems like a good option and controlling the changes in the files is a task you cannot really avoid. If the checksum step were made by a background process at the time you modify a file, the backup process would be lighter, but it would need to be well integrated in the operating system.
* Can I backup a whole operating system with this script?
	* I don't think so. An operating system may need to be stored in a particular filesystem to be functional. TimeVault is intended for data only.
* I can't delete a backup, I have no permissions!
	* TimeVault unsets the writing permissions to prevent accidental deletion of the backups. You can restore those permissions by using ```chown 755``` but you may need admin permissions.

## Credits

* [Apple Inc.](https://www.apple.com/) for setting the main concept with [Time Machine][TimeLink].
* [Mike Rubel](http://www.mikerubel.org/) for inspiring this script with [his article](http://www.mikerubel.org/computers/rsync_snapshots/).

Thank you

## License

Copyright © Jaime García Villena 2017
License GNU General Public License v2.

[TimeLink]: https://en.wikipedia.org/wiki/Time_Machine_(macOS)
