#!/usr/bin/perl

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# USAGE:
#
# CreateMP3CD is a program that creates a directory containing MP3s that can
# easily be burned to a CD and played in a CD player that has MP3 support.
# CreateMP3CD will maintain the order of the songs that is present in an M3U
# playlist file.  It will run both from the command-line and as a nautilus
# script.  The usage on the command-line is as follows:
#
# ./CreateMP3CD directory1 directory2 directory3
#
# This would decend into all of directory1, directory2, and directory3 and
# either copy the MP3s contained therein or convert OGGs to MP3s and place
# the files in a subdirectory of '/tmp/MP3CD'.  Then, this directory can be
# burned to a CD.  To use CreateMP3CD as a nautilus script, simply place
# the file in the "~/.gnome2/nautilus-scripts" directory and set it to be
# executable. Now, simply select the desired directories in nautilus, then
# then right-click and select "scripts >> CreateMP3CD" and the same process
# will proceed.

$DEBUG = 1;
$DEBUG_FILE = "/tmp/output.txt";

$TARGET_DIRECTORY = "/tmp/MP3CD";
$CWD = `pwd`;
$CWD =~ s/[\n|\r]//g;

#create target directory
`mkdir -p \"$TARGET_DIRECTORY\"`;

foreach $arg (@ARGV) {
    convertDirectory($arg, $CWD, $TARGET_DIRECTORY);
}

#FIXME: discover if we're being executed from nautilus or the command-line and
#       interface with the user appropriately.
#notify user that the CD is ready to be burned
`zenity --info --title "Create MP3CD" --text "Your MP3CD is ready to be burned."`;

#convert all of the contents of a directory
sub convertDirectory {
    my $sourceDirectory = shift;  #simple name of directory
    my $parentDirectory = shift;  #full path to source's parent directory
    my $targetDirectory = shift;  #full path to the target directory

    #strip newlines from input
    $sourceDirectory =~ s/[\n|\r]//g;
    $parentDirectory =~ s/[\n|\r]//g;
    $targetDirectory =~ s/[\n|\r]//g;

    #add trailing "/" to source directory if needed
    if ($sourceDirectory !~ m/\/$/) {
	$sourceDirectory .= "/";
    }

    debug("Converting Directory: $sourceDirectory");

    $targetDirectory = $targetDirectory . "/" . $sourceDirectory;
    $sourceDirectory = $parentDirectory . "/" . $sourceDirectory;

    #get the path to the most recently modified m3u file
    debug("ls -t \"$sourceDirectory\"*.m3u");

    my $m3ufile = `ls -t \"$sourceDirectory\"*.m3u`;
    $m3ufile =~ s/[\n|\r]//g;

    debug("m3ufile: $m3ufile");

    #get total number of songs in the m3u file
    my $total = getNumOfSongs($m3ufile);
    my $count = 0;

    #create directory where mp3 files will be placed
    `mkdir -p \"$targetDirectory\"`;
    
    open(M3UFILE, "<$m3ufile");

    #start looping over all of the lines in the m3u file
    while(my $oldfile = <M3UFILE>) {
	#if this line of the m3u file is a comment, skip it
	if ($oldfile =~ m/^\#/) {
	    next;
	}

	#FIXME: doesn't work if file is in different directory from m3u
	$oldfile = `basename \"$oldfile\"`;
	$oldfile = $sourceDirectory . $oldfile;
	$oldfile =~ s/[\n|\r]//g;

	#increment number of files encountered
	$count++;
	
	#get the new filename
	my $newfile = getNewFilename($oldfile, $count, $total);
	$newfile = $targetDirectory . $newfile;
	
	#perform the conversion
	my $result = convertSong($oldfile, $newfile);

	#handle result of convertSong
	if ($result == 0) {
	    debug("Done");
	} else {
	    #stop processing on error
	    #FIXME: may want to do something smarter here...
	    last;
	}
    }

    close(M3UFILE);
}

sub convertSong {
    my $oldfile = shift;
    my $newfile = shift;

    #perform action depending on if the file is an MP3 or an OGG
    if ($oldfile =~ m/\.ogg$/) {
	debug("Converting $oldfile to $newfile...");
	my $result = ogg2mp3("$oldfile", "$newfile");
    } else {
	debug("Copying $oldfile to $newfile...");
	my $result = copyMP3("$oldfile", "$newfile");
    }
    
    return $result;
}

sub copyMP3 {
    my $source = shift;
    my $destination = shift;

    my $command = "cp \"$source\" \"$destination\"";

    return system($command);
}

sub ogg2mp3 {
    my $source = shift;
    my $destination = shift;

    my $command = "ogg123 --quiet -d wav -f - \"$source\" | " .
	"lame --quiet -B 160 -v -V 0 - \"$destination\"";
    
    return system($command);
}

sub getNumOfSongs {
    my $m3ufile = shift;

    my $total = 0;
    open(M3UFILE, "<$m3ufile") or die $?;

    while(my $oldfile = <M3UFILE>) {
	#don't count comments in m3ufile
	if ($oldfile =~ m/^\#/) {
	    next;
	}
	
	#everything else is a file, count it
	$total++;
    }

    close(M3UFILE);
    return $total;
}

sub getNewFilename {
    my $oldfile = shift;

    #count & shift are optional arguments
    my $count = shift;
    my $total = shift;

    #get filename out of full path, strip extra characters
    $oldfile = `basename "$oldfile"`;
    $oldfile =~ s/[\n|\r]//g;

    #create new filename
    my $newfile = $oldfile;
    $newfile = $count . "-$newfile";
    
    #if both $count and $total were passed into the function
    if ($count and $total) {
	#add leading zeros to filename if needed
	my $digitsInTotal = int(log10($total)) + 1;
	my $digitsInCount = int(log10($count)) + 1;
	my $addedZeros = $digitsInTotal - $digitsInCount;
	for (my $i = 0; $i < $addedZeros; $i++) {
	    $newfile = "0" . $newfile;
	}
    }
    
    #since we're making mp3's, change the extension if necessary
    if ($newfile =~ m/\.ogg$/) {
	$newfile =~ s/\.ogg$/.mp3/;
    }

    return $newfile;
}

#performs logarithm base 10 of X
sub log10 {
    $LN_OF_10 = log(10);
    $x = shift;
    
    return (log($x) / $LN_OF_10);
}

sub debug {
    if ($DEBUG != 0) {
	$message = shift;

	open (DEBUG, ">$DEBUG_FILE");
	print DEBUG $message;
	print DEBUG "\n";
	close(DEBUG);
    }
}
