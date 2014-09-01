#!/bin/sh
# Based on nvidia-bug-report
# Adapted and modified for OpenMandriva 
# by TPG (tpgxyz@gmail.com)
# www.openmandriva.org

PATH="/sbin:/usr/sbin:$PATH"

BASE_LOG_FILENAME="omv-bug-report.log"

# check if XZ is present
XZ_CMD=`which xz 2> /dev/null | head -n 1`
if [ $? -eq 0 -a "$XZ_CMD" ]; then
    XZ_CMD="xz -0f --text -T0 -c"
else
    XZ_CMD="cat"
fi

set_filename() {
    if [ "$XZ_CMD" = "xz -0f --text -T0 -c" ]; then
        LOG_FILENAME="$BASE_LOG_FILENAME.xz"
        OLD_LOG_FILENAME="$BASE_LOG_FILENAME.old.xz"
    else
        LOG_FILENAME=$BASE_LOG_FILENAME
        OLD_LOG_FILENAME="$BASE_LOG_FILENAME.old"
    fi
}


usage_bug_report_message() {
    echo "Please include the '$LOG_FILENAME' log file when reporting"
    echo "your bug via the OpenMandriva bugzilla (see issues.openmandriva.org)."
}

usage() {
    echo ""
    echo "$(basename $0): OpenMandriva bug reporting shell script."
    echo ""
    usage_bug_report_message
    echo ""
    echo "$(basename $0) [OPTION]..."
    echo "    -h / --help"
    echo "        Print this help output and exit."
    echo "    --output-file <file>"
    echo "        Write output to <file>. If xz is available, the output file"
    echo "        will be automatically compressed, and \".xz\" will be appended"
    echo "        to the filename. Default: write to omv-bug-report.log(.xz)."
    echo "    --safe-mode"
    echo "        Disable some parts of the script that may hang the system."
    echo ""
}

OMV_BUG_REPORT_CHANGE='$Change: 001 $'
OMV_BUG_REPORT_VERSION=`echo "$OMV_BUG_REPORT_CHANGE" | tr -c -d "[:digit:]"`

# Set the default filename so that it won't be empty in the usage message
set_filename

# Parse arguments: Optionally set output file, or print help
SAVED_FLAGS=$@
while [ "$1" != "" ]; do
    case $1 in
        -o | --output-file )    if [ -z $2 ]; then
                                    usage
                                    exit 1
                                elif [ "$(echo "$2" | cut -c 1)" = "-" ]; then
                                    echo "Warning: Questionable filename"\
                                         "\"$2\": possible missing argument?"
                                fi
                                BASE_LOG_FILENAME="$2"
                                # override the default filename
                                set_filename
                                shift
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

#
# echo_metadata() - echo metadata of specified file
#

echo_metadata() {
    printf "*** ls: "
    /bin/ls -l --full-time "$1" 2> /dev/null

    if [ $? -ne 0 ]; then
        # Run dumb ls -l. We might not get one-second mtime granularity, but
        # that is probably okay.
        ls -l "$1"
    fi
}


#
# append() - append the contents of the specified file to the log
#

append() {
    (
        echo "____________________________________________"
        echo ""

        if [ ! -f "$1" ]; then
            echo "*** $1 does not exist"
        elif [ ! -r "$1" ]; then
            echo "*** $1 is not readable"
        else
            echo "*** $1"
            echo_metadata "$1"
            cat  "$1"
        fi
        echo ""
    ) | $XZ_CMD >> $LOG_FILENAME
}

#
# append_silent() - same as append(), but don't print anything
# if the file does not exist
#

append_silent() {
    (
        if [ -f "$1" -a -r "$1" ]; then
            echo "____________________________________________"
            echo ""
            echo "*** $1"
            echo_metadata "$1"
            cat  "$1"
            echo ""
        fi
    ) | $XZ_CMD >> $LOG_FILENAME
}

#
# append_glob() - use the shell to expand a list of files, and invoke
# append() for each of them
#

append_glob() {
    for i in `ls $1 2> /dev/null;`; do
        append "$i"
    done
}

#
# append_file_or_dir_silent() - if $1 is a regular file, append it; otherwise,
# if $1 is a directory, append all files under it.  Don't print anything if the
# file does not exist.
#

append_file_or_dir_silent() {
    if [ -f "$1" ]; then
        append "$1"
    elif [ -d "$1" ]; then
        append_glob "$1/*"
    fi
}

#
# append_binary_file() - Encode a binary file into a ascii string format
# using 'base64' and append the contents output to the log file
#

append_binary_file() {
    (
        base64=`which base64 2> /dev/null | head -n 1`

        if [ $? -eq 0 -a -x "$base64" ]; then
                if [ -f "$1" -a -r "$1" ]; then
                    echo "____________________________________________"
                    echo ""
                    echo "base64 \"$1\""
                    echo ""
                    base64 "$1" 2> /dev/null
                    echo ""
                fi
        else
            echo "Skipping $1 output (base64 not found)"
            echo ""
        fi

    ) | $XZ_CMD >> $LOG_FILENAME
}

#
# Start of script
#


# check that we are root (needed for `lspci -vxxx` and potentially for
# accessing kernel log files)

if [ `id -u` -ne 0 ]; then
    echo "ERROR: Please run $(basename $0) as root."
    exit 1
fi


# move any old log file (zipped) out of the way

if [ -f $LOG_FILENAME ]; then
    mv $LOG_FILENAME $OLD_LOG_FILENAME
fi


# make sure what we can write to the log file

touch $LOG_FILENAME 2> /dev/null

if [ $? -ne 0 ]; then
    echo
    echo "ERROR: Working directory is not writable; please cd to a directory"
    echo "       where you have write permission so that the $LOG_FILENAME"
    echo "       file can be written."
    echo
    exit 1
fi


# print a start message to stdout

echo ""
echo "omv-bug-report.sh will now collect information about your"
echo "system and create the file '$LOG_FILENAME' in the current"
echo "directory.  It may take several seconds to run."
echo ""
usage_bug_report_message
echo ""
echo -n "Running $(basename $0)...";


# print prologue to the log file

(
    echo "____________________________________________"
    echo ""
    echo "Start of OpenMandriva bug report log file.  Please include this file, along"
    echo "with a detailed description of your problem, when reporting a bug"
    echo "via the OpenMandriva bugzilla (see issues.openmandriva.org)."
    echo ""
    echo "omv-bug-report.sh Version: $OMV_BUG_REPORT_VERSION"
    echo ""
    echo "Date: `date`"
    echo "uname: `uname -a`"
    echo "command line flags: $SAVED_FLAGS"
    echo ""
) | $XZ_CMD >> $LOG_FILENAME


# hostnamectl information

(

    echo ""
    echo "____________________________________________"
    echo ""
    echo "System host infrmation:"
    echo ""
    hostnamectl 2> /dev/null
) | $XZ_CMD >> $LOG_FILENAME

# append useful files
append "/etc/distro-release"
append_silent "/etc/os-release"

# append environment output

(
    echo ""
    echo "____________________________________________"
    echo ""
    echo "Environment settings:"
    echo ""
    systemctl show-environment 2> /dev/null
) | $XZ_CMD >> $LOG_FILENAME

append_silent "/etc/vconsole.conf"
append_silent "/etc/default/grub"

# append useful /proc files
append "/proc/uptime"
append "/proc/cmdline"
append "/proc/cpuinfo"
append "/proc/interrupts"
append "/proc/meminfo"
append "/proc/modules"
append "/proc/version"
append "/proc/asound/cards"
append "/proc/asound/pcm"
append "/proc/asound/modules"
append "/proc/asound/devices"
append "/proc/asound/version"
append "/proc/asound/timers"
append "/proc/asound/hwdep"

for CARD in /proc/asound/card[0-9]*; do
    for CODEC in $CARD/codec*; do
        [ -d $CODEC ] && append_glob "$CODEC/*"
        [ -f $CODEC ] && append "$CODEC"
    done
    for ELD in $CARD/eld*; do
        [ -f $ELD ] && append "$ELD"
    done
done



# Append any config files found in home directories
#cat /etc/passwd \
#    | cut -d : -f 6 \
#    | sort | uniq \
#    | while read DIR; do
#        append_silent "$DIR/.xsession-errors"
#    done


# append installed rpm output

(
    echo ""
    echo "____________________________________________"
    echo ""
    echo "Installed packages:"
    echo ""
    rpm -qa |sort -u 2> /dev/null
) | $XZ_CMD >> $LOG_FILENAME


# lspcidrake information

(
    echo "____________________________________________"
    echo ""

    lspcidrake=`which lspcidrake 2> /dev/null | head -n 1`

    if [ $? -eq 0 -a -x "$lspcidrake" ]; then
        echo "$lspcidrake"
        echo ""
        $lspcidrake -v 2> /dev/null
        echo ""
    else
        echo "Skipping lspcidrake output (lspcidrake not found)"
        echo ""
    fi
) | $XZ_CMD >> $LOG_FILENAME

# lsusb information

(
    echo "____________________________________________"
    echo ""

    lsusb=`which lsusb 2> /dev/null | head -n 1`

    if [ $? -eq 0 -a -x "$lsusb" ]; then
        echo "$lsusb"
        echo ""
        $lsusb 2> /dev/null
        echo ""
    else
        echo "Skipping lsusb output (lsusb not found)"
        echo ""
    fi
) | $XZ_CMD >> $LOG_FILENAME

# dmidecode

(
    echo "____________________________________________"
    echo ""

    dmidecode=`which dmidecode 2> /dev/null | head -n 1`

    if [ $? -eq 0 -a -x "$dmidecode" ]; then
        echo "$dmidecode"
        echo ""
        $dmidecode 2> /dev/null
        echo ""
    else
        echo "Skipping dmidecode output (dmidecode not found)"
        echo ""
    fi
) | $XZ_CMD >> $LOG_FILENAME

# append journalctl output

(
    echo ""
    echo "____________________________________________"
    echo ""
    echo "Systemd boot log:"
    echo ""
    journalctl -b 2> /dev/null
) | $XZ_CMD >> $LOG_FILENAME

# append systemctl --failed output

(
    echo ""
    echo "____________________________________________"
    echo ""
    echo "Systemd failed units:"
    echo ""
    systemctl --no-pager --failed 2> /dev/null
) | $XZ_CMD >> $LOG_FILENAME

# print gcc & g++ version info

(
    which gcc >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "____________________________________________"
        echo ""
        gcc -v 2>&1
    fi

    which g++ >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "____________________________________________"
        echo ""
        g++ -v 2>&1
    fi
) | $XZ_CMD >> $LOG_FILENAME

sync > /dev/null 2>&1

xconfig_file_list=
NEW_LINE="
"

for log_basename in /var/log/Xorg; do
    for i in 0 1 2 3 4 5 6 7; do
        for log_suffix in log ; do
            log_filename="${log_basename}.${i}.${log_suffix}"
            append_silent "${log_filename}"

            # look for the X configuration files/directories referenced by this X log
            if [ -f ${log_filename} -a -r ${log_filename} ]; then
                config_file=`grep "Using config file" ${log_filename} | cut -f 2 -d \"`
                config_dir=`grep "Using config directory" ${log_filename} | cut -f 2 -d \"`
                sys_config_dir=`grep "Using system config directory" ${log_filename} | cut -f 2 -d \"`
                for j in "$config_file" "$config_dir" "$sys_config_dir"; do
                    if [ "$j" ]; then
                        # multiple of the logs we find above might reference the
                        # same X configuration file; keep a list of which X
                        # configuration files we find, and only append X
                        # configuration files we have not already appended
                        echo "${xconfig_file_list}" | grep ":${j}:" > /dev/null
                        if [ "$?" != "0" ]; then
                            xconfig_file_list="${xconfig_file_list}:${j}:"
                            if [ -d "$j" ]; then
                                append_glob "$j/*.conf"
                            else
                                append "$j"
                            fi
                        fi
                    fi
                done

            fi

        done
    done
done



(
    echo "____________________________________________"

    # print epilogue to log file

    echo ""
    echo "End of OpenMandriva bug report log file."
) | $XZ_CMD >> $LOG_FILENAME

# Done

echo " complete."
echo ""

#EOF