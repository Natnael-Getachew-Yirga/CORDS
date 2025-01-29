#!/bin/bash

# =================================================================================
# Configuration
# =================================================================================
BK_DIR="/mnt/nvme2mount/bookkeeper"
ZK_DIR="/mnt/nvme2mount/zookeeper"
LEDGER_DIR="/home/nyerga/CORDS/systems/bk/lm.mp"
JOURNAL_DIR="/home/nyerga/CORDS/systems/bk/jm.mp"
CLIENT_JAR="/home/nyerga/CORDS/systems/bk/bookkeeper-workload/target/bookkeeper-workload-generator-1.0.jar"
LOG_FILE="./bk_test.log"
BK_LOG="./bookie.out"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# =================================================================================
# Helper Functions
# =================================================================================
cleanup() {
    echo -e "${YELLOW}Cleaning up...${RESET}"
    $BK_DIR/bin/bookkeeper-daemon.sh stop bookie
    $ZK_DIR/bin/zkServer.sh stop
    pkill -f 'bookkeeper' >/dev/null 2>&1
    pkill -f 'zookeeper' >/dev/null 2>&1
    rm -f $LOG_FILE
    echo -e "${GREEN}Cleanup complete${RESET}"
    exit 0
}

trap cleanup EXIT

log_message() {
    echo -e "$1" | tee -a $LOG_FILE
}

find_entry_positions() {
    local file=$1
    local pattern="Account"  # Adjust based on known content format
    hexdump -C "$file" | grep -a "$pattern" | cut -d' ' -f1
}

corrupt_specific_entry() {
    local file=$1
    local position=$2
    
    # Convert hex position to decimal
    position=$(printf "%d" "0x$position")
    
    # Corrupt the entry length field (4 bytes before the data)
    position=$((position - 4))
    
    # Create corrupted length field (invalid negative value)
    printf "\xff\xff\xff\xff" | dd of="$file" bs=1 seek=$position conv=notrunc 2>/dev/null
    
    log_message "Corrupted entry length at position: $position"
}

# =================================================================================
# Main Test Execution
# =================================================================================
# Initialize log files
> $BK_LOG
> $LOG_FILE

log_message "${YELLOW}Phase 1: Environment Setup${RESET}"
rm -rf "$ZK_DIR/data" "$ZK_DIR/logs" "$BK_DIR/logs" "$LEDGER_DIR" "$JOURNAL_DIR"
mkdir -p "$ZK_DIR/data" "$ZK_DIR/logs" "$BK_DIR/logs" "$JOURNAL_DIR" "$LEDGER_DIR"

$ZK_DIR/bin/zkServer.sh start
sleep 10
$BK_DIR/bin/bookkeeper shell metaformat -nonInteractive -force
$BK_DIR/bin/bookkeeper-daemon.sh start bookie 
sleep 10

log_message "${GREEN}Environment setup complete${RESET}"

# =================================================================================
# Write Entries and Capture Ledger ID
# =================================================================================
log_message "${YELLOW}Phase 2: Writing Test Entries${RESET}"
java -jar $CLIENT_JAR write > $BK_LOG 2>&1

# Extract ledger ID from logs
LEDGER_ID=$(grep -oP 'Written entry to ledger \K\d+' $BK_LOG | tail -1)
if [ -z "$LEDGER_ID" ]; then
    log_message "${RED}Failed to extract ledger ID from logs${RESET}"
    exit 1
fi
log_message "${GREEN}Ledger created with ID: $LEDGER_ID${RESET}"

# =================================================================================
# Targeted Ledger Corruption
# =================================================================================
log_message "${YELLOW}Phase 3: Targeted Ledger Corruption${RESET}"

# Stop the bookie before corruption
$BK_DIR/bin/bookkeeper-daemon.sh stop bookie
sleep 5

# Find the current ledger file (usually in current/N.log)
CURRENT_LEDGER_FILE=$(ls -tr "$LEDGER_DIR/current/"0.log 2>/dev/null)

if [ -z "$CURRENT_LEDGER_FILE" ]; then
    log_message "${RED}No ledger file found in $LEDGER_DIR/current/${RESET}"
    exit 1
fi

log_message "Targeting ledger file: $CURRENT_LEDGER_FILE"

# Find actual entry positions by looking for known patterns
ENTRY_POSITIONS=$(find_entry_positions "$CURRENT_LEDGER_FILE")

if [ -z "$ENTRY_POSITIONS" ]; then
    log_message "${RED}No entries found in the ledger file${RESET}"
    exit 1
fi

# Corrupt a few specific entries
count=0
for position in $ENTRY_POSITIONS; do
    corrupt_specific_entry "$CURRENT_LEDGER_FILE" "$position"
    count=$((count + 1))
    if [ $count -eq 3 ]; then
        break
    fi
done

log_message "${GREEN}Ledger entry corruption complete${RESET}"

# =================================================================================
# System Recovery Test
# =================================================================================
log_message "${YELLOW}Phase 4: Restarting Bookie${RESET}"
$BK_DIR/bin/bookkeeper-daemon.sh start bookie
sleep 20
#=========================
# Data Validation
# =================================================================================
log_message "${YELLOW}Phase 5: Data Validation${RESET}"
log_message "Attempting to read ledgers 0 to 99"

for i in {0..99}
do
    java -jar $CLIENT_JAR $i >> $BK_LOG 2>&1
done
log_message "${GREEN}Test complete. Full logs available in $BK_LOG${RESET}"