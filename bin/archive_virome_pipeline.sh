#!/bin/bash -x


# Copyright 2012, Dan Nasko
# Last revised 06 July 2012
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# DEPENDENCIES
# None

PROGNAME="archive_virome_pipeline.sh"

USAGE="
Archive VIROME Pipeline

${PROGNAME} [-P pipelineID] [-L /path/to/library.list] [arguments]

-P: ID of the pipeline you wish to archive. (required)
-L: The output list from the db-to-libray file. (required)
-R: The path for the repository root

-h: display help

${PROGNAME} -P CADAD1A2C772 -L ${root}/output_repository/db-load-library/CADAD1A2C772_default/db-load-library.txt.list -R ${root}

"

function error_exit
{

#==============================================================
#  Function for exit due to fatal program error
#	Accepts 1 argument:
#               string containing descriptive error message
#==============================================================
   echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
   exit1
}

if [ $# -eq 0 ]; then echo "$VERSION""$USAGE" >&2; exit 2; fi

while getopts ':r:b:h' OPTION
do
  	case $OPTION in
          P)    pipeline=$OPTARG;;
          L)    library=$OPTARG;;
	  R)	root=$OPTARG;;
          h)    echo "$VERSION""$USAGE" >&2; exit 2;;
        esac
done

# Validate input
if [ ! -f $pipeline ]; then error_exit "The pipeline ID ${pipeline} not found or -P argument not provided"; fi
if [ ! -f $library ]; then error_exit "The library list file ${library} not found or -L argument not provided"; fi
if [ ! -f $root ]; then error_exit "The root directory ${root} not found or -R argument not provided"; fi

# Stop execution on error code
set -e

# Extract library ID
libraryID=`cat `cat ${library}` | cut -f1`

# Create the output repositories
mkdir -p ${root}/archive/${library}
mkdir -p ${root}/archive/${library}/idFiles
mkdir -p ${root}/archive/${library}/xDocs

# Begin archiving files
cp ${root}/output_repository/concatenate_files/${pipeline}*/* ${root}/archive/${library}
cp ${root}/output_repository/db-load-library/${pipeline}*/* ${root}/archive/${library}
cp ${root}/lookup/*${library}* ${root}/archive/${library}
cp ${root}/virome-cache-files/idFiles/*${library}* ${root}/archive/${library}/idFiles
cp ${root}/virome-cache-files/xDocs/*${library}* ${root}/archive/${library}/xDocs
tar -cvfz ${root}/archive/${library}.tgz ${root}/archive/${library}
