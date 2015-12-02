progname=$0

function usage () {
   cat <<EOF
Usage: $progname [-s source database name] [-t target database name]
EOF

}

while getopts ":s:t:" opt; do
   case $opt in

         s )    SOURCE_DATABASE=$OPTARG ;;
         t )    TARGET_DATABASE=$OPTARG ;;
        \?)     echo "unknown option $opt"
                usage;;
   esac
done

USER_NAME=anagha
IP_ADDR=localhost
PASSWORD=evanshall301
t_list='
blast
blastn
blastp
blastx
hmm
orf
sequence
statistics
tRNA
'
for line in $t_list
do
	auto_line=` echo "select auto_increment  from information_schema.tables where table_schema='calliope' AND table_name=\"$line\"" | mysql -h $IP_ADDR -u $USER_NAME -p$PASSWORD $SOURCE_DATABASE `
	autoincrement_value=`echo $auto_line | awk '{print $2}'`
	#echo $line $autoincrement_value
	#echo "ALTER TABLE $line  AUTO_INCREMENT = $autoincrement_value"
	if [[ -z $autoincrement_value ]]
		then
			echo "Warning auto increment variable 0 for $line"
 		else
			final_list=`echo "ALTER TABLE $line  AUTO_INCREMENT = $autoincrement_value" | mysql -h $IP_ADDR -u $USER_NAME -p$PASSWORD $TARGET_DATABASE`
	fi 
done

