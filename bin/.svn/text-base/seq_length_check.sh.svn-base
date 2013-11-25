progname=$0

function usage () {
   cat <<EOF
Usage: $progname [-n nameoffile] [-e extention] [-p fullpath] etc
EOF

}

while getopts ":n:e:p:k:" opt; do
   case $opt in

         n )    nameoffile1=$OPTARG ;;
         e )    RAW_FILE_EXTENSION=$OPTARG ;;
         p )    RAW_FILE_FULL_PATH=$OPTARG ;;
         k )    LIST_FILE_FULL_PATH=$OPTARG ;;
        \?)     echo "unknown option $opt"
                usage;;

   esac
done

#echo " raw file path = $RAW_FILE_FULL_PATH \n list file path = $LIST_FILE_FULL_PATH \n extension =  $extension1"

# File1 will need to be the raw file (so this is the opposite of how it is currently organized)
# File2 will be the list file which contains the full path to the various fasta files and will be passed as a single argument (see above)
# you will need to use the "raw file base" as the pattern to grep in the list file to get the path to the fasta file


if [ -f $LIST_FILE_FULL_PATH ];
then 
	BNAME=`basename $RAW_FILE_FULL_PATH $RAW_FILE_EXTENSION`
	FSA_FULL_PATH=`grep $BNAME $LIST_FILE_FULL_PATH`
#	echo "$BNAME and $FSA_FULL_PATH"	 

	if [ -f $RAW_FILE_FULL_PATH ] && [ -f $FSA_FULL_PATH ];
        then
        	c=`/bin/egrep -c ^\> $FSA_FULL_PATH`
        	d=`/bin/egrep -c ^Query\= $RAW_FILE_FULL_PATH`
	        if [ $c -eq $d ]; then
        	        echo "The number of sequences match"
                	exit 0
	        else
        	        echo "The number of sequences don't match"
                	exit 1
	        fi
	else
        	echo "The files doesn't exist"
        	exit 2
	fi
else
	echo "$LIST_FILE_FULL_PATH does not exist";
fi

#shift $(($OPTIND - 1))


