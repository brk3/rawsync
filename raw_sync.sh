#!/bin/bash

# Copyright (C) 2013 Paul Bourke <pauldbourke@gmail.com>
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

    if [ "$exit_status" -eq "$WRONG_PARAMS" ]; then
        usage
    fi

    exit $exit_status
}

# Define function to call when SIGTERM is received
trap "end '' $interrupted" 1 2 3 15

usage()
{
    cat << EOF

usage: $(basename $0) [ options ]

Arguments:

    -r  Input dir of raw images
    -o  Output dir

Options:
    -i  Takes a directory of raw files, (*.CR2), and copies(imports) them
        to dated subdirectories under <out-dir>. Duplicates will be skipped.

    -c  Move raw files for which there's no matching jpeg in output dir from
        input dir to /tmp/raw_sync_cleanup.

        Images are matched using the file name without extension, i.e.
        IMG_0001.CR2 would be removed unless an IMG_0001.jpg is found.

EOF
}

perform_import() {
    copied_count=0
    skipped_count=0
    for raw_file in $(find $RAW_DIR -name "*.CR2"); do
        # Get the timestamp on the raw file
        DATE=$(exiv2 pr $raw_file | grep -a timestamp | sed \
               's/^.*\([0-9][0-9][0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*$/\1/g' |\
               sed 's/:/_/g')

        # Create the dest dir if it doesn't exist
        COPY_TO_DIR=$OUT_DIR/$DATE
        if [[ ! -d $COPY_TO_DIR ]]; then
            mkdir -p $COPY_TO_DIR
        fi

        # Copy the raw file to the dest if it doesn't exist
        if [[ -f $COPY_TO_DIR/$(basename $raw_file) ]]; then
            echo_color "$COPY_TO_DIR/$(basename $raw_file) exists, skipping" \
                yellow
            ((skipped_count++))
        else
            cp $raw_file $COPY_TO_DIR
            echo_color "Copied $raw_file to $COPY_TO_DIR/$(basename $raw_file)" \
                green
            ((copied_count++))
        fi
    done

    echo
    echo "Import complete. Copied: $copied_count, Skipped: $skipped_count"
}

perform_cleanup() {
    ALL_RAWS=$(find $RAW_DIR -name *.CR2)
    ALL_JPGS=$(find $OUT_DIR -name *.jpg)
    CANDIDATES=()
    SIZE=0  # in bytes
    for RAW in $ALL_RAWS; do
        MATCH=$(echo "${ALL_JPGS[@]:0}" | \
                grep -io -m1 "$(basename $RAW .CR2).jpg")
        if [ -z $MATCH ]; then
            CANDIDATES+=($RAW)
            let SIZE+=$(stat -t $RAW | cut -f 2 -d" ")
        fi
    done

    # Print all candidate files
    echo_color "Candidates for deletion:" "red"
    for i in ${CANDIDATES[@]}; do
        echo $i
    done

    # Print summary
    echo
    echo_color "${#CANDIDATES[@]} candidates for deletion." "green"
    if [ $SIZE -gt 1073741824 ]; then
        SIZE_GB=$(echo "scale=2; $SIZE/1073741824" | bc)
        BIG_SIZE_MSG="($SIZE_GB GB)"
    fi
    echo_color "Total size ${SIZE} bytes $BIG_SIZE_MSG" "green"
    echo

    OK=""
    while [ "$OK" != "OK" ]; do
        echo -n "Review and enter 'OK' to delete: "
        read OK
    done

    if [ "$OK" == "OK" ]; then
        rm -rf ${CANDIDATES[@]}
    fi
}

if [ $# -lt 1 ] ; then
    usage
    exit $WRONG_PARAMS
fi

IMPORT=false
CLEAN=false

while getopts cir:o: opt; do
   case "$opt" in
       i)
           IMPORT=true
           ;;
       c)
           CLEAN=true
           ;;
       r)
           RAW_DIR=$OPTARG
           ;;
       o)
           OUT_DIR=$OPTARG
           ;;
       h)
           usage
           exit 0
           ;;
       \?)
           usage
           exit 0
           ;;
   esac
done

if [[ -z $RAW_DIR ]] || [[ -z $OUT_DIR ]]; then
    usage
    exit $WRONG_PARAMS
fi

if [ $IMPORT == true ]; then
    command -v exiv2 >/dev/null 2>&1 || {
        echo "-i requires the exiv2 command to present. Please run";
        echo "'sudo apt-get install exiv2' or similar."
        exit 1;
    }
    perform_import
fi

if [ $CLEAN == true ]; then
    echo
    echo_color "WARNING!  This will remove all CR2 files from $RAW_DIR " "red"
    echo_color "for which a matching jpg does not exist in $OUT_DIR" "red"
    echo
    OK=""
    while [ "$OK" != "OK" ]; do
        echo -n "Enter OK to continue: "
        read OK
    done
    echo
    perform_cleanup
fi
