#!/usr/bin/env bash
#
# Example of using getopt to parse command line options
# http://stackoverflow.com/a/29754866/1219634 Limitation: All the options
# starting with - have to be listed in --options/--longoptions, else getopt will
# error out. So this cannot be used in wrapper scripts for other applications
# where you plan to pass on the non-wrapper-script options to that wrapped
# application.

#### Usage:   ####
#### sudo ./tm.bash --log=somelog.log --src=dir1/ --cmp=wkly/
#### sudo ./tm.bash --log=somelog.log --src=dir1/ --cmp=wkly/ --added=mon/added/ --deleted=mon/deleted/
#### sudo ./tm.bash -l somelog.log -s dir1/ -c wkly/ -a mon/added/ -d mon/deleted/
###
##
#

# Initialize variables
help=0
debug=0
verbose=0
dummy_arg="__dummy__"
extra_args=("${dummy_arg}") # Because set -u does not allow undefined variables to be used
discard_opts_after_doubledash=0 # 1=Discard, 0=Save opts after -- to ${extra_args}

echo "All pre-getopt arguments: $*"

getopt --test > /dev/null
if [[ $? -ne 4 ]]; then
  echo "$0: 'getopt --test' failed in this environment."
  exit 1
fi


if perl < /dev/null > /dev/null 2>&1  ; then
  echo $0: perl installed.
else
  echo $ requires installed version of perl.
  exit 2
fi

# An option followed by a single colon ':' means that it *needs* an argument.
# An option followed by double colons '::' means that its argument is optional.
# See `man getopt'.
SHORT=hDvl:s:c:a:d:                     # List all the short options
LONG=help,debug,verbose,log:,src:,cmp:,added:,deleted: # List all the long options

# - Temporarily store output to be able to check for errors.
# - Activate advanced mode getopt quoting e.g. via "--options".
# - Pass arguments only via   -- "$@"   to separate them correctly.
# - getopt auto-adds "--" at the end of ${PARSED}, which is then later set to
#   "$@" using the set command.
PARSED=$(getopt --options ${SHORT} \
                --longoptions ${LONG} \
                --name "$0" \
                -- "$@")         #Pass all the args to this script to getopt
if [[ $? -ne 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 3
fi
# Use eval with "$PARSED" to properly handle the quoting
# The set command sets the list of arguments equal to ${PARSED}.
eval set -- "${PARSED}"

echo "Getopt parsed arguments: ${PARSED}"
echo "Effective arguments: $*"
echo "Num args: $#"

while [[ ( ${discard_opts_after_doubledash} -eq 1 ) || ( $# -gt 0 ) ]]
do
    echo "parsing arg: $1"
    case "$1" in
        -l|--log) shift
                     log_file="$1";;
        -s|--src) shift
                     src_dir=`cd "$1"; pwd`
                     src_dir="$src_dir/";;
        -c|--cmp) shift
                     cmp_dir=`cd "$1"; pwd`
                     cmp_dir="$cmp_dir/";;
        -a|--added) shift
                     add_dir=`cd "$1"; pwd`
                     add_dir="$add_dir/";;
        -d|--deleted) shift
                     del_dir=`cd "$1"; pwd`
                     del_dir="$del_dir/";;
        -h|--help) help=1;;
        -D|--debug) debug=1;;
        -v|--verbose) verbose=1;;
        --) if [[ ${discard_opts_after_doubledash} -eq 1 ]]; then break; fi;;
        *) extra_args=("${extra_args[@]}" "$1");;
    esac
    shift                       # Expose the next argument
done

# Now delete the ${dummy_arg} from ${extra_args[@]} array # http://stackoverflow.com/a/16861932/1219634
extra_args=("${extra_args[@]/${dummy_arg}}")

echo =====================================================================================================
echo
echo "help: ${help}, Debug: ${debug}, verbose: ${verbose}, log_file: $log_file, src_dir: $src_dir, cmp_dir: $cmp_dir, add_dir: $add_dir, del_dir: $del_dir,  extra args=${extra_args[*]}"
echo
echo =====================================================================================================





if [ -z "$src_dir" ] && [ -z "$cmp_dir" ] && [ -z "$add_dir" ] && [ -z "$del_dir" ]
then
  echo " $0 Can be used in 2 modes and requires at least 2 arg of dir to be used."
  echo "   Mode 1: source and destination directory"
  echo "   Mode 2: Source, compare,added and deleted directories"
  exit 1
fi

## $0 is the script name, $1 id the first ARG, $2 is second...
echo
echo "$0" is runing...
echo   =======   =======   =======
echo
echo

echo "$0": Remove old log file
echo   =======   =======   =======
# Get last piece of destination path to use a a name for the log file
rm "$log_file"
echo ..."$log_file" ...  Removed
echo
echo



if [ -z "$add_dir" ] && [ -z "$del_dir" ]
then
  echo Runing rsync in full sync mode
  echo
  echo
  echo rsync -aHvx -i  --log-file="$log_file" --delete "$src_dir" "$cmp_dir"
  sudo rsync -aHvx -i  --log-file="$log_file" --delete "$src_dir" "$cmp_dir"
elif ! [ -z "$add_dir" ] && [ -z "$del_dir" ] 
then
  echo $0 Mode 2 Requires an addid dir and a deleted dir.  Please Provide Deleted Dir name.
  echo
  echo
  exit 1
elif [ -z "$add_dir" ] && ![ -z "$del_dir" ] 
then
  echo $0 Mode 2 Requires an added dir and a deleted dir.  Please Provide added Dir name.
  echo
  echo
  exit 1
else
  echo runing rsync in Timemachine sync mode
  echo Clearing older list files
  echo
  echo
  sudo rm tm_del_files.lst
  sudo touch tm_del_files.lst



  echo copying Added Files
  echo
  echo
  echo rsync -aHvx  --log-file="$log_file" --progress --itemize-changes --delete --compare-dest="$cmp_dir"   "$src_dir" "$add_dir" 
  #### this works for deleted:sudo ./timemachine.bash "dir1/" "/home/bakadm/wkly" "mon/added" "../mon/deleted"
  sudo rsync -aHvx  --log-file="$log_file" --progress --itemize-changes --delete --compare-dest="$cmp_dir"  "$src_dir" "$add_dir" 


 echo getting list of deleted files:
  echo
  echo
 ###rsync -ahvxi --dry-run --delete  /home/bakadm/dir1/ /home/bakadm/wkly | grep '^\*deleting' >> tm_del_files.lst
 sudo rsync -aHvxi --dry-run --delete  "$src_dir" "$cmp_dir" | grep '^\*deleting' >> tm_del_files.lst

 echo Remove empty Directories from added dir.
  echo
  echo
 sudo find "$add_dir"/ -depth -type d -exec rmdir {} + 2>/dev/null

 echo Cleaning up file names
  echo
  echo
 sudo perl -pi -e 's/\*deleting\s+//' tm_del_files.lst 

 echo saving deleted files:
  echo
  echo
 echo rsync -aHvxi --files-from=tm_del_files.lst "$cmp_dir" "$del_dir"
 sudo rsync -aHvxi --files-from=tm_del_files.lst "$cmp_dir" "$del_dir"
 
fi

echo
echo Remove tmp files
  sudo rm tm_del_files.lst
echo
echo "$0": Completed rsync
echo
echo "$0": End
echo   =======   =======   =======
echo



#### examples:
# rsync -aHvx  --log-file=test.log --progress --itemize-changes --delete --compare-dest=../../wkly /home/bakadm/dir1/ /home/bakadm/mon/added
# rsync -aHvx  --log-file=test.log --progress --itemize-changes --delete --backup --backup-dir=../mon/deleted /home/bakadm/dir1/ /home/bakadm/wkly

#  /usr/local/bin/rsyncad /share/kds-cad-srvr/ /media/bakups/cad/wkly /media/bakups/cad/sat
