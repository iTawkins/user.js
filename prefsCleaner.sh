#!/usr/bin/env bash

## prefs.js cleaner for Linux/Mac
## author: @claustromaniac
## version: 1.6

## special thanks to @overdodactyl and @earthlng for a few snippets that I stol..*cough* borrowed from the updater.sh

currdir=$(pwd)

## get the full path of this script (readlink for Linux, greadlink for Mac with coreutils installed)
sfp=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || greadlink -f "${BASH_SOURCE[0]}" 2>/dev/null)

## fallback for Macs without coreutils
if [ -z "$sfp" ]; then sfp=${BASH_SOURCE[0]}; fi

## change directory to the Firefox profile directory
cd "$(dirname "${sfp}")"

## download method priority: curl -> wget
DOWNLOAD_METHOD=''
if command -v curl >/dev/null; then
  DOWNLOAD_METHOD='curl --max-redirs 3 -so'
elif command -v wget >/dev/null; then
  DOWNLOAD_METHOD='wget --max-redirect 3 --quiet -O'
else
  echo -e "This script requires curl or wget.\nProcess aborted"
  exit 1
fi

fQuit() {
	## change directory back to the original working directory
	cd "${currdir}"
	[ "$1" -eq 0 ] && echo -e "\n$2" || echo -e "\n$2" >&2
	exit $1
}

fUsage() {
	echo -e "\nUsage: $0 [-s]"
	echo -e "
Optional Arguments:
    -s           Start immediately
    -u           Update prefsCleaner.sh and execute silently.  Do not seek confirmation."
}

fFF_check() {
	# there are many ways to see if firefox is running or not, some more reliable than others
	# this isn't elegant and might not be future-proof but should at least be compatible with any environment
	while [ -e lock ]; do
		echo -e "\nThis Firefox profile seems to be in use. Close Firefox and try again.\n" >&2
		read -r -p "Press any key to continue."
	done
}

fClean() {
	# the magic happens here
	prefs="@@"
	prefexp="user_pref[ 	]*\([ 	]*[\"']([^\"']+)[\"'][ 	]*,"
	while read -r line; do
		if [[ "$line" =~ $prefexp && $prefs != *"@@${BASH_REMATCH[1]}@@"* ]]; then
			prefs="${prefs}${BASH_REMATCH[1]}@@"
		fi
	done <<< "$(grep -E "$prefexp" user.js)"

	while IFS='' read -r line || [[ -n "$line" ]]; do
		if [[ "$line" =~ ^$prefexp ]]; then
			if [[ $prefs != *"@@${BASH_REMATCH[1]}@@"* ]]; then
				echo "$line"
			fi
		else
			echo "$line"
		fi
	done < "$1" > prefs.js
}

fStart() {
	if [ ! -e user.js ]; then
		fQuit 1 "user.js not found in the current directory."
	elif [ ! -e prefs.js ]; then
		fQuit 1 "prefs.js not found in the current directory."
	fi

	fFF_check
	mkdir -p prefsjs_backups
	bakfile="prefsjs_backups/prefs.js.backup.$(date +"%Y-%m-%d_%H%M")"
	mv prefs.js "${bakfile}" || fQuit 1 "Operation aborted.\nReason: Could not create backup file $bakfile"
	echo -e "\nprefs.js backed up: $bakfile"
	echo "Cleaning prefs.js..."
	fClean "$bakfile"
	fQuit 0 "All done!"
}

## returns the version number of a prefsCleaner.sh file
get_prefsCleaner_version() {
  echo "$(sed -n '5 s/.*[[:blank:]]\([[:digit:]]*\.[[:digit:]]*\)/\1/p' "$1")"
 }

## updates the prefsCleaner.sh file based on the latest public version
update_prefsCleaner() {
  declare -r tmpfile="$(download_file 'https://raw.githubusercontent.com/arkenfox/user.js/master/prefsCleaner.sh')"
  [ -z "${tmpfile}" ] && echo -e "Error! Could not download updater.sh" && return 1 # check if download failed

  if [[ $(get_prefsCleaner_version "$SCRIPT_FILE") == $(get_prefsCleaner_version "${tmpfile}") ]]; then
    echo -e "There is no update available"
    return 0
  else
  mv "${tmpfile}" "$SCRIPT_FILE"
  chmod u+x "$SCRIPT_FILE"
  "$SCRIPT_FILE" "$@" -d
  exit 0
  fi
 }

echo -e "\n\n"
echo "                   ╔══════════════════════════╗"
echo "                   ║     prefs.js cleaner     ║"
echo "                   ║    by claustromaniac     ║"
echo "                   ║           v1.6           ║"
echo "                   ╚══════════════════════════╝"
echo -e "\nThis script should be run from your Firefox profile directory.\n"
echo "It will remove any entries from prefs.js that also exist in user.js."
echo "This will allow inactive preferences to be reset to their default values."
echo -e "\nThis Firefox profile shouldn't be in use during the process.\n"
echo -e "\nIn order to proceed, select a command below by entering its corresponding number.\n"

## Flag implementation
while getopts "su" OPTION
do
	case $OPTION in
	    s)
		fStart
		;;
	    u)
		download_file
		update_prefsCleaner
		;;
	esac
done

select option in Start Update Help Exit; do
	case $option in
		Start)
			fStart
			;;
		Update)
                        download_file
		        update_prefsCleaner
			;;
		Help)
			fUsage
			echo -e "\nThis script creates a backup of your prefs.js file before doing anything."
			echo -e "It should be safe, but you can follow these steps if something goes wrong:\n"
			echo "1. Make sure Firefox is closed."
			echo "2. Delete prefs.js in your profile folder."
			echo "3. Delete Invalidprefs.js if you have one in the same folder."
			echo "4. Rename or copy your latest backup to prefs.js."
			echo "5. Run Firefox and see if you notice anything wrong with it."
			echo "6. If you do notice something wrong, especially with your extensions, and/or with the UI, go to about:support, and restart Firefox with add-ons disabled. Then, restart it again normally, and see if the problems were solved."
			echo -e "If you are able to identify the cause of your issues, please bring it up on the arkenfox user.js GitHub repository.\n"
			;;
		Exit)
			fQuit 0
			;;
	esac
done
