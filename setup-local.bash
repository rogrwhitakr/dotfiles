#!/usr/bin/bash

# ######################################################################################
# BASH PROFILE SETUP
#   HISTORY:
#
#   2018-06-23 - First Creationv
#   2018-06-23 - add one-shot service for pulling files
#   2021-09-03 - add local updater
#
# ######################################################################################

# global vars
readonly version="0.9.0"

function usage {
	cat <<EOF
${0} [OPTION]... [FILE]...

this script sets up sourcing of:
	.bashrc.d/*.bash

	it creates a subdirectory "$HOME"/.bashrc.d/, which is in turn populated with distinct files
	these are then referenced in the bashrc file.
	templates are sourced from github.com

PREREQUISITES / REQUIREMENTS:
	network connectivity

VERSION:
	Version ${version:-' not defined'}
EOF
}


print() {

	# DESC: pretty print text, lines
	# ARGS: 1 -> Color, line
	#		choices are:
	#			RED
	#			YELLOW
	#			BLUE
	#			GREEN
	#			NOC (no color)
	#			LINE
	#
	# ARGS: 2 -> Text, line element
	# OUTS: colorised text, (non-colorised) line
	# LIMITS:
	#		cannot take formatters (newline,tabs,etc...)
	# EXAMPLE:
	#		print RED "text to be printed red"
	#		print "text to be printed without color"
	#		print LINE
	#		print LINE #

	case "${1^^}" in
	RED)
		printf '\033[0;31m%s\033[0m\n' "${2}"
		;;
	YELLOW)
		printf '\e[33m%s\033[0m\n' "${2}"
		;;
	BLUE)
		printf '\e[33m%s\033[0m\n' "${2}"
		;;
	GREEN)
		printf '\e[0;32m%s\033[0m\n' "${2}"
		;;
	LOG)
		printf '%(%F %T)T :: %s\n' -1 "${2}"
		;;

	# this option is for running a script with systemd
	# systemd does not create a terminal (and its size),
	# so the $TERM variable stays empty. using a fixed length
	LOGLINE)
		separator="-" # separator default
		logline="["
		for ((i = 1; i <= 50; i++)); do # make the line
			logline+="${separator}"
		done
		logline+="]"
		printf '%s\n' "${logline}" # regurgitate to terminal
		;;
	TIMELINE)
		separator="-"            # separator default
		line="[---[$(date +"%Y-%m-%d %H:%M:%S")]"                 # adding to a "line" variable
		term_size="$(tput cols)" # get number of columns
		if ([[ ! -z "$2" ]] && [[ "${#2}" == 1 ]]); then # set custom the separator (length must be 1)
			separator="${2}"
		fi
		for ((i = 1; i <= "${term_size}-26"; i++)); do # make the line
			line+="${separator}"
		done
		line+="]"
		printf '%s\n' "${line}" # regurgitate to terminal
		;;	
	LINE)
		separator="-"            # separator default
		line="["                 # adding to a "line" variable
		term_size="$(tput cols)" # get number of columns
		if ([[ ! -z "$2" ]] && [[ "${#2}" == 1 ]]); then # set custom the separator (length must be 1)
			separator="${2}"
		fi
		for ((i = 1; i <= "${term_size}-2"; i++)); do # make the line
			line+="${separator}"
		done
		line+="]"
		printf '%s\n' "${line}" # regurgitate to terminal
		;;
	*)
		printf '\033[0m%s\033[0m\n' "${1}"
		;;
	esac
}

function script_finish {

	# DESC: Trap exits with cleanup function
	# ARGS: exit code -> trap <script_finish> EXIT INT TERM
	# OUTS: None (so far)
	# INFO: ERROR_CODE is put in local var, b/c otherwise one gets the return code
	#       of the most recently completed command
	#       (and i dont care for knowing "echo" ran successfully...)

	local ERROR_CODE="$?"
	if [[ "${ERROR_CODE}" != 0 ]]; then
		printf "ERROR"
		usage
		# remove directory .bashrc.d ?
		rm -fr "$HOME"/.bashrc.d
	fi
}

function add_to_file {
	local destination="${1}"
	local file="${2}"
	local directory="${3}"

	echo -e "
# BEGIN SOURCE ${file^^} DEFINITION
if [[ -f ~/${directory}/${file} ]]; then
	. ~/${directory}/${file}
fi 
# END SOURCE ${file^^} DEFINITION" >>"$HOME/${destination}"
}

function main {
	# DESC: the core function of the script
	# NOTE: main
	# ARGS: $@: Arguments provided to the script
	# OUTS: Magic!

	# vars
	readonly _directory=".bashrc.d"
	readonly url="https://raw.githubusercontent.com/rogrwhitakr/dotfiles/main/.bashrc.d"

	declare -a sources=('.bashrc' '.bash_profile')
	declare -a files=('alias.bash' 'function.bash' 'export.bash' 'program.bash' 'git.bash' 'powerline.bash' 'alias-flatpak.bash')

	trap script_finish EXIT INT TERM

	# we start out in the executing users home dir
	# we create in the home of the user excuting the unit file!
	cd "$HOME"

	print line
	print RED "Starting"
	# we create .bashrc if it doesn't exist
	for source in "${sources[@]}"; do
		if [[ ! -f "$HOME"/"${source}" ]]; then
			printf "\ncreating ${source}"
			touch "$HOME"/"${source}"
		fi
	done

	# setting up directory
	# -> parentheses here DO NOT WORK
	# they hinder expansion of "$HOME"
	if [[ ! -d "$HOME"/"${_directory:-.bashrc.d}" ]]; then
		printf "\nCreating directory "$HOME"/${_directory:-.bashrc.d}"
		mkdir "$HOME"/"${_directory:-.bashrc.d}"
		cd "$HOME"/"${_directory:-.bashrc.d}"
	else
		cd "$HOME"/"${_directory:-.bashrc.d}"
	fi

	for file in "${files[@]}"; do
		printf "\ncollecting raw file from github: ${file}, saving to $(pwd)"
		wget "${url}/${file}" --output-document="${file}" --quiet
	done

	printf "\nremove old sourcing, if applicable"
	for source in "${sources[@]}"; do
		for file in "${files[@]}"; do
			sed -i "/SOURCE ${file^^} DEFINITION/,+5d" "$HOME"/"${source}"
		done
	done

	printf "\nadd sourcing to bash sources"
	for source in "${sources[@]}"; do
		for file in "${files[@]}"; do
			add_to_file "${source}" "${file}" "${_directory}"
		done
	done

	printf "\nCompleted."
	printf "\n"
	print line
	print GREEN "Finished"
}

# Make it rain
main "$@"
