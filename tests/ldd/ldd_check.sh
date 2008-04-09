#! /bin/bash
###################################################
# run test on build kiwi images packed in rpm     #
# Pavel Nemec <pnemec@suse.cz>                    #
# Orig. Author: Stanislav Brabec <sbrabec@suse.cz>#
# License GPL v3                                  #
#                                                 #
# Test which check ldd on all binary system check #
# installed packages                              #
###################################################
# return 0 - if no broken file is found
# return 1 - if any broken file is found



SEARCH_DIRS_BIN="/bin /sbin /usr/sbin /usr/bin /opt/gnome/bin /opt/kde3/bin/ /usr/X11R6/bin"
SEARCH_DIRS_LIB="/lib /lib64 /usr/lib /usr/lib64 /usr/X11R6/lib  /usr/X11R6/lib64"
SEARCH_DIRS=""

# Base of temporary files names.
LIST=~/.revdep-rebuild

shopt -s nullglob
shopt -s expand_aliases
unalias -a

SONAME="not found"
SONAME_GREP=fgrep


#temporary files
SYSTEM_FILES_LIST=$(mktemp)
LD_PAH_LIST=$(mktemp)



SEARCH_DIRS="$SEARCH_DIRS_BIN $SEARCH_DIRS_LIB"
while [ $# -gt 0 ] 
do
    case $1 in
    	-b) #binary
		echo "searching binary"
		SEARCH_DIRS="$SEARCH_DIRS_BIN"
		;;
	-l) #library
		echo "searching library"
		SEARCH_DIRS="$SEARCH_DIRS_LIB"
		;;
	#default is not needed, default is search trough all
    esac
    shift
done

#echo "search dir: $SEARCH_DIRS"
echo -n -e "Collecting system files..."
echo "" >  $SYSTEM_FILES_LIST  


find $SEARCH_DIRS -type f \( -perm -u=x -perm -g=x -perm -o=x -o -name '*.so' -o -name '*.so.*' \) 2>/dev/null >$SYSTEM_FILES_LIST

echo -e " done."

# search broken
echo -n -e "Collecting complete LD_LIBRARY_PATH..."
(
	grep '.*\.so\(\|\..*\)$' <$SYSTEM_FILES_LIST | sed 's:/[^/]*$::' 
	sed '/^#/d;s/#.*$//' </etc/ld.so.conf 
)| uniq | sort | uniq | tr '\n' : | tr -d '\r' | sed 's/:$//' > $LD_PAH_LIST
echo -e " done."
export COMPLETE_LD_LIBRARY_PATH="$(cat $LD_PAH_LIST)"
#
# check dynamic links

# return value
#reti=0
echo -n -e "Checking dynamic linking$WORKING_TEXT..."
echo ""
for FILE in $(cat $SYSTEM_FILES_LIST)
do
# Note: double checking seems to be faster than single
	# with complete path (special add ons are rare).
	LD_LIBRARY_PATH="$COMPLETE_LD_LIBRARY_PATH"
	ldd "$FILE" 2>/dev/null | $SONAME_GREP -q "$SONAME"
	miss=$?
	if [ ${miss} -eq 0 ] 
	then
		echo "broken $FILE (requires $(ldd "$FILE" | sed -n 's/	\(.*\) => not found$/\1/p' | tr '\n' ' ' | sed 's/ $//' ))"
		reti=1
	fi
done

rm $LD_PAH_LIST
rm $SYSTEM_FILES_LIST
exit $reti

