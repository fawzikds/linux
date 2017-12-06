#!/usr/bin/env bash
#
# Example of using getopt to parse command line options
# http://stackoverflow.com/a/29754866/1219634 Limitation: All the options
# starting with - have to be listed in --options/--longoptions, else getopt will
# error out. So this cannot be used in wrapper scripts for other applications
# where you plan to pass on the non-wrapper-script options to that wrapped
# application.
#### Usage:   ####
#### e.g.  sudo /oc_10_bkup.bash  /kdscloud /kdscloud_BK/mon  root mysqlPasswd kdscloud /kdscloud /kdscloud_BK/wkly/ /kdscloud_bk/mon/added/ /kdscloud_bk/mon/deleted/ /var/log/oc_10.log

# Initialize variables
help=0
debug=0
dry-run=""
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
SHORT=hDtvl:r:p:n:s:b:c:e:                     # List all the short options
LONG=help,debug,verbose,log:,cldsrc:,clddest:,mysqroot:,mysqpass:,mysqdbnm:,datasrc:,datacmp:,dataadded:.datadeleted: # List all the long options

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
        -r|--mysqroot) shift
                     mysqroot="$1";;
        -p|--mysqpass) shift
                     mysqpass="$1";;
        -n|--mysqdbnm) shift
                     mysqdbnm="$1";;
		     ### The location of Cloud files e.g. /var/www/nextcloud ###
        -s|--cldsrc) shift
                     cldsrc=`cd "$1"; pwd`
                     cldsrc="$cldsrc/";;
		     ### The location of Cloud data files files e.g. /var/www/nextcloud/data or /kdscloud ###
		     ### -b= begin, -c = compare, -e= end of data ###
        -b|--datasrc) shift
                     datasrc=`cd "$1"; pwd`
                     datasrc="$datasrc/";;
        -c|--datacmp) shift
                     datacmp=`cd "$1"; pwd`
                     datacmp="$datacmp/";;
        -e|--datadest) shift
                     datadest=`cd "$1"; pwd`
                     datadest="$datadest/";;
        -l|--log) shift
                     log_file="$1";;
        -h|--help) help=1;;
        -D|--debug) debug=1;;
        -t|--dry-run) dry-run="--dry-run";;
        -v|--verbose) verbose=1;;
        --) if [[ ${discard_opts_after_doubledash} -eq 1 ]]; then break; fi;;
        *) extra_args=("${extra_args[@]}" "$1");;
    esac
    shift                       # Expose the next argument
done

# Now delete the ${dummy_arg} from ${extra_args[@]} array # http://stackoverflow.com/a/16861932/1219634
extra_args=("${extra_args[@]/${dummy_arg}}")

if  [ $verbose -eq "1" ]  ; then
	echo
	echo "$0 : version 1.00 ...."
	echo
	if ! [ -z "$mysqroot" ] ; then echo "mysqroot=$mysqroot"; fi;
	if ! [ -z "$mysqpass" ] ; then echo "mysqpass=$mysqpass"; fi;
	if ! [ -z "$mysqdbnm" ] ; then echo "mysqdbnm=$mysqdbnm"; fi;
	if ! [ -z "$cldsrc" ] ; then echo "cldsrc=$cldsrc"; fi;
	if ! [ -z "$datasrc" ] ; then echo "datasrc=$datasrc"; fi;
	if ! [ -z "$datacmp" ] ; then echo "datacmp=$datacmp"; fi;
	if ! [ -z "$datadest" ] ; then echo "datadest=$datadest"; fi;
	if ! [ -z "$log_file" ] ; then echo "log_file=$log_file"; fi;
        echo
fi
# Reuire 6 Parameters for specifying the source and destination directories.
if  [ $help -eq "1" ] || [ -z "$mysqroot" ] || [ -z "$mysqpass" ] || [ -z "$mysqdbnm" ] || [ -z "$cldsrc" ] || [ -z "$datasrc" ] || [ -z "$datacmp" ] ; then
  echo " !!! 6 non empty Parameters are required:"
  echo "   1- Mysql Root name. e.g. root"
  echo "   2- Mysql Root password. e.g. password"
  echo "   3- Mysql database name. e.g. kdscloud"
  echo "   4- Nextcloud Source Dir: location of current nextcloud files. e.g. /var/www/nextcloud"
  echo "   5- nextcloud Current Location of nextcloud user DATA files. e.g. /kdsloud"
  echo "   6- nextcloud weekly backup location e.g. /share/kds-bak-srvr/kdscloud/wkly"
  echo "   !! Optional Parmaters"
  echo "   7- nextcloud daily backup location e.g.  /share/kds-bak-srvr/kdscloud/mon"
  echo "   8- Location of log file for current script."
  echo
  echo "sudo $0  -r root -p mysqlpasswd  -n kdscloud -s /var/www/nextcloud -b /kdscloud -c /kdscloud_BK/wkly/ -e /kdscloud_bk/mon/ -l /var/log/$0.log"
  echo
  echo " $0: Exiting..."
  exit 1
  echo
fi

echo
if [ -z "$datadest" ]; then cmndest="$datacmp";  echo "cmndest = datacmp =$cmndest" 
   else cmndest="$datadest"; echo "cmndest = datadest =$cmndest"
fi


echo  When backing up ownCloud server, there are 5 things to copy:
echo     "1- backing up directory: $cmndest/config"
sudo rsync -Aax "$dry-run" $cldsrc/config "$cmndest"

echo     "2- backing up directory: $cmndest/themes"
sudo rsync -Aax "$dry-run" $cldsrc/themes "$cmndest"

echo     "3- backing up directory: $cmndest/apps"
sudo rsync -Aax "$dry-run" $cldsrc/apps "$cmndest"

echo     "4- backing up ownCloud Mysql database."
sudo mysqldump --single-transaction --defaults-file="/etc/samba/smb.crd"  -h localhost -u "$mysqroot"  -p"$mysqpass"  "$mysqdbnm" > "$cmndest"/"$mysqdbnm"_db.dump
sudo mysqldump --single-transaction -h localhost -u "$mysqroot" -p"$mysqpass"  "$mysqdbnm" > $cmndest/$mysqdbnm_db.dump


echo     "5- backing up nextcloud user's data files"
echo "copying/comparing Nextcloud's data directory:"
### this if statment is redundent, i could have put this could in the previous check on datadest. 
### i seperated it out here for clarity.
   if [ -z "$datadest" ]; then
     echo "Rsync Weekly..."
     /usr/local/bin/timemachine.bash -l "$dry-run" "$log_file_tm.log" -s "$datasrc" -c "$datacmp/data/"
   else
     echo "Rsync Daily..."
     /usr/local/bin/timemachine.bash -l "$dry-run" "$log_file_tm.log" -s "$datasrc" -c "$datacmp/data/" -a "$datadest/added" -d "$datadest/deleted"
   fi;

echo $0: Completed
