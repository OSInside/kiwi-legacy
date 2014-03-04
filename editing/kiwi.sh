# kiwi bash completion script

_kiwi() {
	local cur prev opts base
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	#========================================
	# Basic options we complete
	#----------------------------------------
	local cmd=/usr/sbin/kiwi
	for name in $(cat $cmd | grep -E "\".*?\".*=>");do
		if [[ $name =~ ^\" ]];then
			name=$(echo $name | tr -d "\"" |\
				cut -f1 -d\| | cut -f1 -d=)
			opts="$opts --$name"
		fi
	done
	#========================================
	# Complete arguments for basic options
	#----------------------------------------
	case "${prev}" in
		--build|--prepare)
			local running
			for name in /usr/share/kiwi/image/*;do
				if [[ $name =~ boot ]];then
					continue
				fi
				running="$running $(basename $name)"
			done
			COMPREPLY=( $(compgen -W "${running}" -- ${cur}) )
			return 0
		;;
		--type)
			local schema=/usr/share/kiwi/modules/KIWISchema.rnc
			local running=$(for i in $(cat $schema |\
				grep -A 3 "attribute image {");do echo $i;done|\
				grep ^\" | cut -f2 -d "\"")
			COMPREPLY=( $(compgen -W "${running}" -- ${cur}) )
			return 0
		;;
		*)
		;;
	esac
	COMPREPLY=($(compgen -W "${opts}" -- ${cur}))  
	return 0
}

complete -F _kiwi kiwi
