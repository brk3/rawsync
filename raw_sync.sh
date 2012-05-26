#!/bin/bash

# Copyright (C) 2012 Paul Bourke <pauldbourke@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Template from http://goo.gl/6sz40

PATH="/sbin:/usr/sbin:/bin:/usr/bin"

# Error codes
WRONG_PARAMS=5
INTERRUPTED=99
DEFAULT_ERROR=1

echo_color() {
    message="$1"
    color="$2"

    red_begin="\033[01;31m"
    green_begin="\033[01;32m"
    yellow_begin="\033[01;33m"
    color_end="\033[00m"

    # Set color to normal when there is no color
    [ ! "$color" ] && color_begin="$color_end"

    if [ "$color" == "red" ]; then
        color_begin="$red_begin"
    fi

    if [ "$color" == "green" ]; then
        color_begin="$green_begin"
    fi

    if [ "$color" == "yellow" ]; then
        color_begin="$yellow_begin"
    fi

    echo -e "${color_begin}${message}${color_end}"
}

end() {
    message="$1"
    exit_status="$2"

    if [ -z "$exit_status" ]; then
        exit_status="0"
    fi

    if [ ! "$exit_status" -eq "0" ]; then
        echo_color "$message" "red"
    else
        echo_color "$message" "green"
    fi

    if [ "$exit_status" -eq "$wrong_params" ]; then
        dohelp
    fi

    exit $exit_status
}

# Define function to call when SIGTERM is received
trap "end 'Interrupted' $interrupted" 1 2 3 15

usage()
{
    cat << EOF

    usage: $(basename $0) <raw-files-dir> <out-dir>

    Takes a directory of raw files, (*.CR2), and copies them to dated
    subdirectories under <out-dir>. Duplicates will be skipped.

EOF
}

RAW_DIR=$1
OUT_DIR=$2
if [[ -z $RAW_DIR ]] || [[ -z $OUT_DIR ]]; then
    usage
    exit $WRONG_PARAMS
fi

for raw_file in $(find $RAW_DIR -name "*.CR2"); do
    # Get the timestamp on the raw file
    DATE=$(exiv2 pr $raw_file | grep -a timestamp | sed \
           's/^.*\([0-9][0-9][0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*$/\1/g' | \
           sed 's/:/_/g')

    # Create the dest dir if it doesn't exist
    COPY_TO_DIR=$OUT_DIR/$DATE
    if [[ ! -d $COPY_TO_DIR ]]; then
        mkdir $COPY_TO_DIR
    fi

    # Copy the raw file to the dest if it doesn't exist
    if [[ -f $COPY_TO_DIR/$(basename $raw_file) ]]; then
        echo_color "$COPY_TO_DIR/$(basename $raw_file) exists, skipping" yellow
    else
        cp $raw_file $COPY_TO_DIR
        echo_color "$raw_file copied to $COPY_TO_DIR/$(basename $raw_file)" \
            green
    fi
done
