#!/usr/bin/env bash

# Rzync Backup - Backup Runner - Backup Multiple hosts

CWD="$(dirname $0)/"

# Source Config
. ${CWD}../etc/backup.conf

# Source Functions
. ${CWD}functions.sh;

HOSTS_DIR="/${POOL_NAME}/hosts/"
LOCKFILE="/var/run/$(basename $0 | sed s/\.sh//).pid"
LOGFILE="/${POOL_NAME}/logs/backup.log"
SKIP_POST_HOOK=false

if [ ! $(whoami) = "root" ]; then
    echo "Error: Must run as root."
    exit 99
fi

# Check to see if we are already running / locked, limit to one instance per host
if [ -f ${LOCKFILE} ] ; then
    logMessage 3 $LOGFILE "Error: Already running, or locked. Lockfile exists [$(ls -ld $LOCKFILE)]."
    exit 99
else
    echo $$ > ${LOCKFILE}
    # Upon exit, remove lockfile.
    trap "{ rm -f ${LOCKFILE}; }" EXIT
fi

showUsage() {
    echo "
Rzync Backup

Backup Runner - Backup Multiple Hosts

  usage: bashup-runner.sh [ -c <comment> ] [hosts ...]

  options:
    -a | --all                 backup all hosts
    -c | --comment <comment>   backup annotation
    -e | --expiry <days>       backup expiry in days
    --skip-post-hook           skip post-backup hook execution
    [hosts ...]                one or more hosts to backup
    -h                         this help message
    ";
}

# Parse Opts
while true; do
    case "$1" in
        -a | --all ) HOSTS=$(ls ${HOSTS_DIR}); shift ;;
        -c | --comment ) ANNOTATION=$2; shift 2 ;;
        -e | --expiry ) EXPIRY=$2; shift 2 ;;
        --skip-post-hook ) SKIP_POST_HOOK=true; shift ;;
        -h | --help ) showUsage; exit 128 ;;
        -- ) shift; break ;;
        * ) if [ ! "$1" == "" ]; then HOSTS="$HOSTS $*"; fi; shift; break ;;
    esac
done

if [ "$HOSTS" == '' ]; then
    echo "Error: Please specify host or hostnames name as the arguments, or --all."
    showUsage
    exit 128
fi

logMessage 1 $LOGFILE "Info: Begin backup run of hosts $(echo ${HOSTS})" 

export ANNOT=$ANNOTATION
export EXP=$EXPIRY
export CWD=$CWD
  for host in $HOSTS; do
  echo $host; done | xargs -n 1 -P ${CONCURRENCY}  sh -c '/backup/bin/backup.sh $1 "$ANNOT" $EXP' sh

# Execute post-backup hook if configured
if [ "$SKIP_POST_HOOK" = "true" ]; then
    logMessage 1 $LOGFILE "Info: Skipping post-backup hook (--skip-post-hook specified)"
elif [ -n "$BACKUP_POST_HOOK" ]; then
    logMessage 1 $LOGFILE "Info: Executing post-backup hook: ${BACKUP_POST_HOOK}"
    # Capture output and redirect to logfile
    HOOK_OUTPUT=$(eval $BACKUP_POST_HOOK 2>&1)
    HOOK_RETVAL=$?

    # Log the output
    if [ -n "$HOOK_OUTPUT" ]; then
        echo "$HOOK_OUTPUT" | while IFS= read -r line; do
            logMessage 1 $LOGFILE "Hook output: $line"
        done
    fi

    if [ $HOOK_RETVAL -eq 0 ]; then
        logMessage 1 $LOGFILE "Info: Post-backup hook completed successfully"
    elif [ $HOOK_RETVAL -eq 2 ]; then
        logMessage 2 $LOGFILE "Warning: Post-backup hook completed with warnings (some datasets failed to sync)"
    else
        logMessage 3 $LOGFILE "Error: Post-backup hook failed with exit code ${HOOK_RETVAL}"
    fi
fi

exit 0
