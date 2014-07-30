# kiwi bash completion script

_kiwi() {
	#========================================
	# Init completion
	#----------------------------------------
	local cur prev opts
	_get_comp_words_by_ref cur prev

	#========================================
	# Current base mode
	#----------------------------------------
	local cmd=$(echo $COMP_LINE | cut -f2 -d " " | tr -d -)

	#========================================
	# Items to complete
	#----------------------------------------
	__kiwi_descriptions
	__kiwi_types

	#========================================
	# Global options
	#----------------------------------------
	opt_global="
		--logfile
		--debug
		--yes
		--nocolor
		--version
		--help
	"
	#========================================
	# Basic commands
	#----------------------------------------
	opts="$opt_global
		--bootcd
		--bootusb
		--bootvm
		--build
		--bundle-build
		--clone
		--convert
		--create
		--createhash
		--createpassword
		--info
		--list
		--installcd
		--installstick
		--installpxe
		--prepare
		--test-image
		--check-config
		--upgrade
		--describe
		--init-cache
		--setup-splash
	"
	#========================================
	# Command specific options to complete
	#----------------------------------------
	opt_bootcd="
	"
	opt_bootusb="
	"
	opt_bootvm="
		--bootvm-system
		--bootvm-disksize
	"
	opt_build="
		--recycle-root
		--force-bootstrap
		--cache
		--add-profile
		--set-repo
		--set-repotype
		--set-repoalias
		--set-repoprio
		--add-repo
		--add-repotype
		--add-repoalias
		--add-repoprio
		--ignore-repos
		--package-manager
		--check-kernel
		--destdir
		--type
		--strip
		--prebuiltbootimage
		--archive-image
		--isocheck
		--lvm
		--fs-blocksize
		--fs-journalsize
		--fs-inodesize
		--fs-inoderatio
		--fs-max-mount-count
		--fs-check-interval
		--fat-storage
		--partitioner
		--check-kernel
		--mbrid
		--gzip-cmd
		--disk-start-sector
		--disk-sector-size
		--disk-alignment
		--add-package
		--add-pattern
		--del-package
		--edit-bootconfig
		--edit-bootinstall
		--grub-chainload
		--targetdevice
		--targetstudio
	"
	opt_bundlebuild="
		--bundle-id
		--destdir
	"
	opt_clone="
	"
	opt_convert="
		--format
	"
	opt_create="
		--targetdevice
		--targetstudio
		--recycle-root
		--force-bootstrap
		--check-kernel
		--destdir
		--type
		--strip
		--prebuiltbootimage
		--archive-image
		--isocheck
		--lvm
		--fs-blocksize
		--fs-journalsize
		--fs-inodesize
		--fs-inoderatio
		--fs-max-mount-count
		--fs-check-interval
		--fat-storage
		--partitioner
		--check-kernel
		--mbrid
		--cache
		--gzip-cmd
		--disk-start-sector
		--disk-sector-size
		--disk-alignment
		--add-profile
		--edit-bootconfig
		--edit-bootinstall
		--grub-chainload
	"
	opt_createhash="
	"
	opt_createpassword="
	"
	opt_info="
		--select
		--add-profile
		--ignore-repos
		--package-manager
		--set-repo
		--set-repotype
		--set-repoalias
		--set-repoprio
		--add-repo
		--add-repotype
		--add-repoalias
		--add-repoprio
	"
	opt_list="
	"
	opt_installcd="
		--installcd-system
	"
	opt_installstick="
		--installstick-system
	"
	opt_installpxe="
		--installpxe-system
	"
	opt_prepare="
		--force-new-root
		--root
		--recycle-root
		--force-bootstrap
		--cache
		--add-profile
		--set-repo
		--set-repotype
		--set-repoalias
		--set-repoprio
		--add-repo
		--add-repotype
		--add-repoalias
		--add-repoprio
		--ignore-repos
		--package-manager
		--del-package
		--add-package
		--add-pattern
	"
	opt_testimage="
		--test-case
		--type
	"
	opt_checkconfig="
	"
	opt_upgrade="
		--add-package
		--add-pattern
		--del-package
	"
	opt_describe="
	"
	opt_initcache="
	"
	opt_setupsplash="
	"
	eval cmd_options=\$opt_$cmd
	if [ ! -z "$cmd_options" ];then
		opts=$cmd_options
	fi

	#========================================
	# Command option parameters completion
	#----------------------------------------
	case "${prev}" in
		--build|--prepare|--clone|--info|--test-image|--init-cache)
			__comp_reply "$descriptions"
			__warn_no_description
			return 0
		;;
		--type)
			__comp_reply "$types"
			return 0
		;;
		*)
		;;
	esac
	#========================================
	# Command option completion
	#----------------------------------------
	__comp_reply "$opts"
	return 0
}

#========================================
# kiwi_types
#----------------------------------------
function __kiwi_types {
	local schema=/usr/share/kiwi/modules/KIWISchema.rnc
	types=$(for i in $(cat $schema |\
		grep -A 3 "attribute image {");do echo $i;done|\
		grep ^\" | cut -f2 -d "\"")
}

#========================================
# kiwi_descriptions
#----------------------------------------
function __kiwi_descriptions {
	local name
	for name in /usr/share/kiwi/image/*;do
		if [[ $name =~ boot ]];then
			continue
		fi
		descriptions="$descriptions $(basename $name)"
	done
}

#========================================
# warn_no_description
#----------------------------------------
function __warn_no_description {
	if [ -z "$descriptions" ]; then
		echo -en "\n ==> no descriptions found\n$COMP_LINE"
	fi
}

#========================================
# comp_reply
#----------------------------------------
function __comp_reply {
	word_list=$@
	COMPREPLY=($(compgen -W "$word_list" -- ${cur}))
}

complete -F _kiwi -o default kiwi
