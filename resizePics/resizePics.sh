#!/bin/bash

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
#
# USAGE:
# resizePics is a script that will resize pictures whose filenames are passed
# to it on the command line.  It uses zenity to ask the user what size to make
# the pictures, creates a suitably named subdirectory of the current working
# directory, resizes the pictures and stores them in the new directory.  It
# even has a progress bar to show how far along it is.
#
# resizePics can be used on the command line or as a nautilus script.  To use
# it as a nautilus script, place it in the "~/.gnome2/nautilus-scripts"
# directory and make it executable.  Now, simply select the pictures you would
# like to resize in nautilus, right-click and select "scripts >> resizePics".

size=`zenity --entry --title='ResizePics' --text='Enter the desired size for the selected pictures.' --entry-text='800x600'`

dir="Thumbnails-$size"

mkdir -p $dir

num_done=0
total=$#

(for file in $@
do

    #get just the filename
    shortfile=`basename "$file"`

    #convert to smaller size & store in $dir
    convert -size $size "$file" -resize $size "$dir/$shortfile"

    num_done=$(($num_done+1))

    percent=$(($num_done*100/total))

    echo $percent

done) | zenity --progress --title="ResizePics" --text="Resizing Pictures to $size" --auto-close
