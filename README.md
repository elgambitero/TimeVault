# TimeVault


TimeVault is a backup script written in bash, that takes advantage of a particularity of the EXT4 format to make incremental timestamped backups rather than copying the whole thing again.

Simplified usage:

```
./timeVault.sh <source folder> <destination folder>
```

and then hit the 4th option "Perform a Complete Cycle", and let it sit for a long while.

### Requirements

* The destination folder must be contained in a volume formated in EXT4 format.
* The destination folder must be writtable by the user.

## Disclaimer

**Use at your own risk. I take no responsibility from any loss or data, or any kind of damage or negative consequence derived from the use of this script.** That being said, I hope this script is useful to back up your stuff.

## Description

TimeVault is based on the scripts presented in [this article by Mike Rubel](http://www.mikerubel.org/computers/rsync_snapshots/). These make use of the ```rsync``` and ```cp``` commands to make copies of the same folder, with the unchanged files linked to the previous backup.

The author makes a good description about the mechanics involved in the process. ```cp -al``` is used to make a hardlinked (more on that later) copy of the old tree, and ```rsync --delete``` to add the new files, and delete the ones that were deleted on the source folder.

However, this approach doesn't take in account those files that are simply moved, so ```rsync``` will just erase them and create them somewhere else, without really noticing that they are the same file; therefore taking new space in the process.

For this, TimeVault adds a previous stage in which a checksum is calculated for every file in the source folder, so identical files are detected and not stored again. A consequence of this, is that if there are identical files on the source folder, those are stored only once on the disk. Potentially resulting in the backup being smaller than the original folder in some cases.



