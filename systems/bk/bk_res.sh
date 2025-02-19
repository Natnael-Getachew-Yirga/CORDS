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

# =================================================================================
# Main Test Execution
# =================================================================================
# Initialize log files
> $BK_LOG
> $LOG_FILE

log_message "${YELLOW}Phase 1: Environment Setup${RESET}"
#rm -rf "$ZK_DIR/data" "$ZK_DIR/logs" "$BK_DIR/logs" "$LEDGER_DIR" "$JOURNAL_DIR"
#mkdir -p "$ZK_DIR/data" "$ZK_DIR/logs" "$BK_DIR/logs" "$JOURNAL_DIR" "$LEDGER_DIR"

$ZK_DIR/bin/zkServer.sh start
sleep 10
#$BK_DIR/bin/bookkeeper shell metaformat -nonInteractive -force
$BK_DIR/bin/bookkeeper-daemon.sh start bookie 
sleep 10

log_message "${GREEN}Environment setup complete${RESET}"

# =================================================================================
# Write Entries and Capture Ledger ID
# =================================================================================
log_message "${YELLOW}Phase 2: Writing Test Entries${RESET}"
java -jar $CLIENT_JAR 2 100 > $BK_LOG 2>&1

# Extract ledger ID from logs
LEDGER_ID=$(grep -oP 'Written entry to ledger \K\d+' $BK_LOG | tail -1)
if [ -z "$LEDGER_ID" ]; then
    log_message "${RED}Failed to extract ledger ID from logs${RESET}"
    exit 1
fi
log_message "${GREEN}Ledger created with ID: $LEDGER_ID${RESET}"

# Keep script running
while true; do
    sleep 1
done