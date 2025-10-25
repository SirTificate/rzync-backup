#!/usr/bin/env bash

# Rzync Backup - Reset Monitoring Status
# Sends SUCCESS status for all configured backup hosts to clear old errors

CWD="$(dirname $0)/"

# Source Config
. ${CWD}../etc/backup.conf

# Source Functions
. ${CWD}functions.sh;

HOSTS_DIR="/${POOL_NAME}/hosts/"
ANNOTATION=${1:-"Manual status reset"}
DRY_RUN=false

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

showUsage() {
    echo "
Rzync Backup - Monitoring Status Reset

Sends SUCCESS status to monitoring for all configured hosts.
Use this to clear old error states after fixing issues.

Usage: $0 [options]

Options:
    --dry-run | -n     Show what would be sent without actually sending
    --message | -m     Custom message (default: 'Manual status reset')
    --host <hostname>  Reset only specific host instead of all
    -h | --help        Show this help message

Examples:
    $0                                    # Reset all hosts
    $0 --dry-run                          # Show what would be sent
    $0 --message \"After NSCA fix\"         # Custom message
    $0 --host example.com                 # Reset only one host
    "
}

# Parse arguments
SPECIFIC_HOST=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -m|--message)
            ANNOTATION="$2"
            shift 2
            ;;
        --host)
            SPECIFIC_HOST="$2"
            shift 2
            ;;
        -h|--help)
            showUsage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            showUsage
            exit 1
            ;;
    esac
done

echo "==================================================================="
echo "Monitoring Status Reset"
echo "==================================================================="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN MODE - No messages will be sent${NC}"
    echo ""
fi

# Check if monitor handler exists
if [ ! -f "$MONITOR_HANDLER" ]; then
    echo "Error: Monitor handler not found: $MONITOR_HANDLER"
    exit 1
fi

# Get list of hosts
if [ -n "$SPECIFIC_HOST" ]; then
    if [ -d "${HOSTS_DIR}${SPECIFIC_HOST}" ]; then
        HOSTS="$SPECIFIC_HOST"
        echo "Resetting status for: ${SPECIFIC_HOST}"
    else
        echo "Error: Host not found: ${SPECIFIC_HOST}"
        exit 1
    fi
else
    if [ ! -d "$HOSTS_DIR" ]; then
        echo "Error: Hosts directory not found: $HOSTS_DIR"
        exit 1
    fi

    HOSTS=$(ls ${HOSTS_DIR} 2>/dev/null)
    if [ -z "$HOSTS" ]; then
        echo "Error: No hosts found in ${HOSTS_DIR}"
        exit 1
    fi

    HOST_COUNT=$(echo "$HOSTS" | wc -w)
    echo "Found ${HOST_COUNT} host(s) to reset"
fi

echo "Message: ${ANNOTATION}"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo "Sending SUCCESS status to monitoring..."
else
    echo "Would send SUCCESS status to monitoring..."
fi

echo ""

# Counter
SUCCESS_COUNT=0
FAILED_COUNT=0

# Send status for each host
for HOST in $HOSTS; do
    # Skip if not a directory
    if [ ! -d "${HOSTS_DIR}${HOST}" ]; then
        continue
    fi

    # Reset DISABLED variable before checking host config
    DISABLED=false

    # Check if host is disabled
    if [ -f "${HOSTS_DIR}${HOST}/c/backup.conf" ]; then
        source "${HOSTS_DIR}${HOST}/c/backup.conf"
        if [ "${DISABLED}" = "true" ]; then
            echo -e "${BLUE}[SKIP]${NC} ${HOST} (disabled)"
            continue
        fi
    fi

    # Prepare message
    MESSAGE="Backup OK - ${ANNOTATION}"
    SERVICE_NAME="${NSCA_SERVICE_NAME:-backup}"
    RETURN_CODE=0  # 0 = OK, 1 = WARNING, 2 = CRITICAL

    if [ "$DRY_RUN" = true ]; then
        echo -e "${BLUE}[DRY RUN]${NC} ${HOST} -> ${SERVICE_NAME}: ${MESSAGE}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        # Send to monitoring
        if $MONITOR_HANDLER "${SERVICE_NAME}" "${RETURN_CODE}" "${MESSAGE}" "${HOST}" >/dev/null 2>&1; then
            echo -e "${GREEN}[OK]${NC} ${HOST}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo -e "${YELLOW}[FAILED]${NC} ${HOST} - Could not send to monitoring"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    fi

    # Small delay to avoid overwhelming the monitoring system
    if [ "$DRY_RUN" = false ]; then
        sleep 0.5
    fi
done

echo ""
echo "==================================================================="
echo "Summary"
echo "==================================================================="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "Dry run completed:"
    echo "  Would send: ${SUCCESS_COUNT}"
else
    echo "Status reset completed:"
    echo "  Successfully sent: ${SUCCESS_COUNT}"
    if [ $FAILED_COUNT -gt 0 ]; then
        echo "  Failed: ${FAILED_COUNT}"
    fi
fi

echo ""

if [ "$DRY_RUN" = true ]; then
    echo "Run without --dry-run to actually send the messages"
else
    echo "Check your monitoring system to verify status updates"
fi

echo "==================================================================="

exit 0