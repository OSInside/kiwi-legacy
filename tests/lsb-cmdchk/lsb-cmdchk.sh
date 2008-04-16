#! /bin/bash
###################################################
# run test on build kiwi images packed in rpm     #
# Pavel Nemec <pnemec@suse.cz>                    #
#                                                 #
# Test which use LSB test cmdchk parse output and #
# print valuable informations                     #
#################################################### 
# return 0 - if all LSB commands are found
# return 1 - if some commands are missing

#requires awk,mktemp


BINARY="/opt/lsb/bin/lsbcmdchk"
JOURNAL=$(mktemp)

# test needed binary, just for usure
if [ ! -f "${BINARY}" ]
then 
	echo "$BINARY not found"
	ls -l $BINARY
	rm $JOURNAL
	exit 1
fi

#execute test, no need to catch return value
output=$($BINARY -j $JOURNAL 2>&1)

#parse output in more convinient way
cat $JOURNAL | awk -F "|" '
BEGIN {
	reti=0
	command=""
	
}
$1 == "200"{
	split($NF,parts," ")	
	command=parts[length(parts)]
}
$1 == "220"{
	if($NF ~ "PASS"){
		pass_array[length(pass_array)]=command
		next
	}
	if($NF ~ "FAIL"){
		fail_array[length(fail_array)]=command 
		next
	}	
}
$1 == "80" { command=""}
END{
	if(length(fail_array)>0){
		print "Missing command:"
		printf "%s ",fail_array[1]
		for(i=1;i<length(fail_array);i++){
			printf ", %s",fail_array[i]
		}
		printf "\n"
		reti=1
	}
	# do not print tested commands
	#if(length(pass_array)>0){
	#	print "Found commands:" 
	#	printf "%s, ",pass_array[1]
	#	for(i=1;i<length(pass_array);i++){
	#		printf ", %s",pass_array[i]
	#	}
	#	printf "\n"
	#}
	exit reti
}
'
reti=$?
rm $JOURNAL
exit $reti
