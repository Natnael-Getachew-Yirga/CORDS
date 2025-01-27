#!/bin/bash

# Initialize paths
BK_DIR="/mnt/nvme2mount/bookkeeper"
ZK_DIR="/mnt/nvme2mount/zookeeper"
LEDGER_DIR="/home/nyerga/CORDS/systems/bk/l-m"
JOURNAL_DIR="/home/nyerga/CORDS/systems/bk/j-m"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

#===============================================================================
# Stop running instances of ZooKeeper and BookKeeper if any
#===============================================================================
echo -e "1.${YELLOW}Stopping any running ZooKeeper and BookKeeper instances...${RESET}"
$ZK_DIR/bin/zkServer.sh stop
$BK_DIR/bin/bookkeeper-daemon.sh stop bookie

#===============================================================================
# Clean up old directories
#===============================================================================
echo -e "2.${YELLOW}Cleaning up previous test directories...${RESET}"
rm -rf "$ZK_DIR/data" "$ZK_DIR/logs"
rm -rf "$BK_DIR/logs" 
rm -rf "$LEDGER_DIR" "$JOURNAL_DIR"
echo -e "3.${GREEN}Cleanup completed${RESET}"
sleep 5
#===============================================================================
# Create necessary directories
#===============================================================================
echo -e "4.${YELLOW}Creating necessary directories...${RESET}"
mkdir -p "$ZK_DIR/data" "$ZK_DIR/logs"
mkdir -p "$BK_DIR/logs" "$JOURNAL_DIR" "$LEDGER_DIR"
echo -e "5.${GREEN}Directories created${RESET}"

#===============================================================================
# Start ZooKeeper
#===============================================================================
echo -e "8.${YELLOW}Starting ZooKeeper${RESET}"
$ZK_DIR/bin/zkServer.sh start
echo -e "9.${YELLOW}Waiting for 10 seconds to ensure ZooKeeper is ready${RESET}"
sleep 10
echo -e "10.${GREEN}ZooKeeper started${RESET}"

#===============================================================================
# Initialize BookKeeper metadata
#===============================================================================
echo -e "11.${YELLOW}Initializing BookKeeper metadata${RESET}"
$BK_DIR/bin/bookkeeper shell metaformat -nonInteractive -force
echo -e "12.${GREEN}BookKeeper metadata initialized${RESET}"

#===============================================================================
# Start BookKeeper services
#===============================================================================
echo -e "13.${YELLOW}Starting BookKeeper services${RESET}"
$BK_DIR/bin/bookkeeper-daemon.sh start bookie
echo -e "14.${YELLOW}Waiting for 10 seconds to ensure BookKeeper is ready${RESET}"
sleep 10
echo -e "15.${GREEN}BookKeeper services started${RESET}"

# Function to cleanup on script termination
cleanup() {
    echo -e "16.${YELLOW}Stopping BookKeeper and Zookeeper services${RESET}"
    $BK_DIR/bin/bookkeeper-daemon.sh stop bookie
    $ZK_DIR/bin/zkServer.sh stop
    pkill -f 'bookkeeper' >/dev/null 2>&1
    pkill -f 'zookeeper' >/dev/null 2>&1
    echo "All services stopped."
    exit 0
}
# Set up trap for cleanup on script termination
trap cleanup EXIT

# Keep script running
while true; do
    sleep 1
done