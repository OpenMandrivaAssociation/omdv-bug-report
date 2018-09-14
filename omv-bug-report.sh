#!/bin/sh
# Based on nvidia-bug-report
# Adapted and modified for OpenMandriva 
# by TPG (tpgxyz@gmail.com)
# www.openmandriva.org

PATH="/sbin:/usr/sbin:$PATH"

BASE_LOG_FILENAME="omv-bug-report.log"

# check if XZ is present
XZ_CMD="$(which xz 2> /dev/null | head -n 1)"
if [ $? -eq 0 ] && [ "$XZ_CMD" ]; then
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
    print '%s\n' "Please include the '$LOG_FILENAME' log file when reporting"
    print '%s\n' "your bug via the OpenMandriva bugzilla (see issues.openmandriva.org)."
}

usage() {
    print '%s\n' ""
    print '%s\n' "$(basename $0): OpenMandriva bug reporting shell script."
    print '%s\n' ""
    usage_bug_report_message
    print '%s\n' ""
    print '%s\n' "$(basename $0) [OPTION]..."
    print '%s\n' "    -h / --help"
    print '%s\n' "        Print this help output and exit."
    print '%s\n' "    --output-file <file>"
    print '%s\n' "        Write output to <file>. If xz is available, the output file"
    print '%s\n' "        will be automatically compressed, and \".xz\" will be appended"
    print '%s\n' "        to the filename. Default: write to omv-bug-report.log(.xz)."
    print '%s\n' "    --safe-mode"
    print '%s\n' "        Disable some parts of the script that may hang the system."
    print '%s\n' ""
}

OMV_BUG_REPORT_CHANGE='$Change: 002 $'
OMV_BUG_REPORT_VERSION="$(echo "$OMV_BUG_REPORT_CHANGE" | tr -c -d "[:digit:]")"

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
        print '%s\n' "____________________________________________"
        print '%s\n' ""

        if [ ! -f "$1" ]; then
            print '%s\n' "*** $1 does not exist"
        elif [ ! -r "$1" ]; then
            print '%s\n' "*** $1 is not readable"
        else
            print '%s\n' "*** $1"
            echo_metadata "$1"
            cat  "$1"
        fi
        print '%s\n' ""
    ) | $XZ_CMD >> $LOG_FILENAME
}

#
# append_silent() - same as append(), but don't print anything
# if the file does not exist
#

append_silent() {
    (
        if [ -f "$1" ] && [ -r "$1" ]; then
            print '%s\n' "____________________________________________"
            print '%s\n' ""
            print '%s\n' "*** $1"
            echo_metadata "$1"
            cat  "$1"
            print '%s\n' ""
        fi
    ) | $XZ_CMD >> $LOG_FILENAME
}

#
# append_glob() - use the shell to expand a list of files, and invoke
# append() for each of them
#

append_glob() {
    for i in $(ls $1 2> /dev/null;); do
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
        base64="$(which base64 2> /dev/null | head -n 1)"

        if [ $? -eq 0 ] && [ -x "$base64" ]; then
                if [ -f "$1" ] && [ -r "$1" ]; then
                    print '%s\n' "____________________________________________"
                    print '%s\n' ""
                    print '%s\n' "base64 \"$1\""
                    print '%s\n' ""
                    base64 "$1" 2> /dev/null
                    print '%s\n' ""
                fi
        else
            print '%s\n' "Skipping $1 output (base64 not found)"
            print '%s\n' ""
        fi

    ) | $XZ_CMD >> $LOG_FILENAME
}

#
# Start of script
#


# check that we are root (needed for `lspci -vxxx` and potentially for
# accessing kernel log files)

if [ "$(id -u)" -ne 0 ]; then
    print '%s\n' "ERROR: Please run $(basename $0) as root."
    exit 1
fi


# move any old log file (zipped) out of the way

if [ -f $LOG_FILENAME ]; then
    mv $LOG_FILENAME $OLD_LOG_FILENAME
fi


# make sure what we can write to the log file

touch $LOG_FILENAME 2> /dev/null

if [ $? -ne 0 ]; then
    print '%s\n' ""
    print '%s\n' "ERROR: Working directory is not writable; please cd to a directory"
    print '%s\n' "       where you have write permission so that the $LOG_FILENAME"
    print '%s\n' "       file can be written."
    print '%s\n' ""
    exit 1
fi


# print a start message to stdout

print '%s\n' ""
print '%s\n' "omv-bug-report.sh will now collect information about your"
print '%s\n' "system and create the file '$LOG_FILENAME' in the current"
print '%s\n' "directory.  It may take several seconds to run."
print '%s\n' ""
usage_bug_report_message
print '%s\n' ""
print '%s\n' "Running $(basename $0)...";


# print prologue to the log file

(
    print '%s\n' "____________________________________________"
    print '%s\n' ""
    print '%s\n' "Start of OpenMandriva bug report log file.  Please include this file, along"
    print '%s\n' "with a detailed description of your problem, when reporting a bug"
    print '%s\n' "via the OpenMandriva bugzilla (see issues.openmandriva.org)."
    print '%s\n' ""
    print '%s\n' "omv-bug-report.sh Version: $OMV_BUG_REPORT_VERSION"
    print '%s\n' ""
    print '%s\n' "Date: $(date)"
    print '%s\n' "uname: $(uname -a)"
    print '%s\n' "command line flags: $SAVED_FLAGS"
    print '%s\n' ""
) | $XZ_CMD >> $LOG_FILENAME


# hostnamectl information

(

    print '%s\n' ""
    print '%s\n' "____________________________________________"
    print '%s\n' ""
    print '%s\n' "System host infrmation:"
    print '%s\n' ""
    hostnamectl 2> /dev/null
) | $XZ_CMD >> $LOG_FILENAME

# append useful files
append "/etc/distro-release"
append_silent "/etc/os-release"

# append environment output

(
    print '%s\n' ""
    print '%s\n' "____________________________________________"
    print '%s\n' ""
    print '%s\n' "Environment settings:"
    print '%s\n' ""
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
    print '%s\n' ""
    print '%s\n' "____________________________________________"
    print '%s\n' ""
    print '%s\n' "Installed packages:"
    print '%s\n' ""
    rpm -qa | sort -u 2> /dev/null
) | $XZ_CMD >> $LOG_FILENAME


# lspcidrake information

(
    print '%s\n' "____________________________________________"
    print '%s\n' ""

    lspci="$(which lspci 2> /dev/null | head -n 1)"

    if [ $? -eq 0 ] && [ -x "$lspci" ]; then
        print '%s\n' "$lspci"
        print '%s\n' ""
        $lspci -v 2> /dev/null
        print '%s\n' ""
    else
        print '%s\n' "Skipping lspci output (lspci not found)"
        print '%s\n' ""
    fi
) | $XZ_CMD >> $LOG_FILENAME

# lsusb information

(
    print '%s\n' "____________________________________________"
    print '%s\n' ""

    lsusb="$(which lsusb 2> /dev/null | head -n 1)"

    if [ $? -eq 0 ] && [ -x "$lsusb" ]; then
        print '%s\n' "$lsusb"
        print '%s\n' ""
        $lsusb 2> /dev/null
        print '%s\n' ""
    else
        print '%s\n' "Skipping lsusb output (lsusb not found)"
        print '%s\n' ""
    fi
) | $XZ_CMD >> $LOG_FILENAME

# dmidecode

(
    print '%s\n' "____________________________________________"
    print '%s\n' ""

    dmidecode="$(which dmidecode 2> /dev/null | head -n 1)"

    if [ $? -eq 0 ] && [ -x "$dmidecode" ]; then
        print '%s\n' "$dmidecode"
        print '%s\n' ""
        $dmidecode 2> /dev/null
        print '%s\n' ""
    else
        print '%s\n' "Skipping dmidecode output (dmidecode not found)"
        print '%s\n' ""
    fi
) | $XZ_CMD >> $LOG_FILENAME

# append journalctl output

(
    print '%s\n' ""
    print '%s\n' "____________________________________________"
    print '%s\n' ""
    print '%s\n' "Systemd boot log:"
    print '%s\n' ""
    journalctl -b 2> /dev/null
) | $XZ_CMD >> $LOG_FILENAME

# append systemctl --failed output

(
    print '%s\n' ""
    print '%s\n' "____________________________________________"
    print '%s\n' ""
    print '%s\n' "Systemd failed units:"
    print '%s\n' ""
    systemctl --no-pager --failed 2> /dev/null
) | $XZ_CMD >> $LOG_FILENAME

# print gcc & g++ version info

(
    which gcc >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        print '%s\n' "____________________________________________"
        print '%s\n' ""
        gcc -v 2>&1
    fi

    which g++ >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        print '%s\n' "____________________________________________"
        print '%s\n' ""
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
            if [ -f ${log_filename} ] && [ -r ${log_filename} ]; then
                config_file="$(grep "Using config file" ${log_filename} | cut -f 2 -d \")"
                config_dir="$(grep "Using config directory" ${log_filename} | cut -f 2 -d \")"
                sys_config_dir="$(grep "Using system config directory" ${log_filename} | cut -f 2 -d \")"
                for j in "$config_file" "$config_dir" "$sys_config_dir"; do
                    if [ "$j" ]; then
                        # multiple of the logs we find above might reference the
                        # same X configuration file; keep a list of which X
                        # configuration files we find, and only append X
                        # configuration files we have not already appended
                        echo "${xconfig_file_list}" | grep ":${j}:" > /dev/null
                        if [ "$?" != '0' ]; then
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
    print '%s\n' "____________________________________________"

    # print epilogue to log file

    print '%s\n' ""
    print '%s\n' "End of OpenMandriva bug report log file."
) | $XZ_CMD >> $LOG_FILENAME

# Done

print '%s\n' " complete."
print '%s\n' ""

#EOF
