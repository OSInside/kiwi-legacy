#! /bin/bash
###################################################
# run test on build kiwi images packed in rpm     #
# Pavel Nemec <pnemec@suse.cz>                    #
#                                                 #
# Test which check for rpm, rpm db and verify all #
# installed packages                              #
#################################################### 
# return 0 - if no broken rpm is found
# return 1 - if any broken file is found
# expect path to chroot as first parametr

# todo: proper rpm parsing: http://itso.iu.edu/Post_Install_Package_Verification
#       it is needed?

#requires awk, rpm, mktemp


CHROOT=$1
if [ -z $CHROOT ]
then
	echo "expecting path to CHROOT as first parametr"
	exit 1
fi

# first do the naive test for aaa_base
TMP=$(
	rpm --root $CHROOT -qv aaa_base | \
	awk '\
		$0 !~ /^aaa_base.*/ {print 1} 
		$0 ~ /^aaa_base.*/ {print 0}'
	)
# this check should be done in xml description as prerequirement
if [ "${TMP}" -ne 0 ]
then
	echo "base package not found rpm db missing?"
	return 1;
fi

TMP=$(mktemp)
rpm -V -a --root $CHROOT | awk -v tmp=$TMP '
BEGIN{
	miss="missing";
	deps="Unsatisfied";
	deps_string="Unsatisfied dependencies for"
	other_counter=0
	
}
$1 == miss {
	for(i=0;i<NF;i++){
		if(substr($i,1,1)=="/"){
			missing_array[length(missing_array)]=$i
			next;
		}
	}
}
$1 == deps{
	package=$0
	gsub(deps_string,"",package)
	package=substr(package,1,index(package,":")-1)
	deps_array[length(deps_array)]=package
	next
}
{
	other_counter++
}
	
END{
	if(length(missing_array)>0){
		print "Missing file(s):" > tmp
		for(i=0;i<length(missing_array);i++){
			print "\t"missing_array[i] > tmp
		}
	}
	if(length(deps_array)>0){
		print deps_string":" > tmp
		for(i=0;i<length(deps_array);i++){
			print "\t"deps_array[i] > tmp
		}
	}
	if(other_counter>0) 
		print "Others " other_counter " errors ">tmp
}
'
size=$(cat $TMP | wc -l)
if [ $size -gt 0 ]
then 
	cat $TMP
	rm $TMP
	exit 1
else 
	rm $TMP
	exit 0
fi
