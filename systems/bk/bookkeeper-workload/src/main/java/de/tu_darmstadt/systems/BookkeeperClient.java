package de.tu_darmstadt.systems;

import org.apache.bookkeeper.client.BookKeeper;
import org.apache.bookkeeper.client.LedgerEntry;
import org.apache.bookkeeper.conf.ClientConfiguration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;
import java.util.Enumeration;

public class BookkeeperClient {
    private static final String ZK_CONNECTION = "localhost:2181";
    private static final Logger LOG = LoggerFactory.getLogger(BookkeeperClient.class);
    
    // ANSI escape code for green color
    private static final String ANSI_GREEN = "\u001B[32m";
    private static final String ANSI_RESET = "\u001B[0m";
    
    public static void main(String[] args) {
        if (args.length < 2) {
            System.out.println("Usage: java -jar client.jar <mode> <count>");
            System.out.println("Modes:");
            System.out.println("  1: Multiple entries in single ledger (count = number of entries)");
            System.out.println("  2: Single entry in multiple ledgers (count = number of ledgers)");
            System.out.println("  read <ledgerId>: Read entries from specified ledger");
            return;
        }
        
        try {
            ClientConfiguration conf = new ClientConfiguration();
            conf.setMetadataServiceUri("zk://" + ZK_CONNECTION + "/ledgers");
            BookKeeper bkClient = new BookKeeper(conf);
            
            String mode = args[0];
            
            if (mode.equals("read")) {
                // Read mode
                long ledgerId = Long.parseLong(args[1]);
                readLedger(bkClient, ledgerId);
            } else {
                // Write modes
                int count = Integer.parseInt(args[1]);
                
                if (mode.equals("1")) {
                    // Mode 1: Multiple entries in single ledger
                    writeMultipleEntriesToSingleLedger(bkClient, count);
                } else if (mode.equals("2")) {
                    // Mode 2: Single entry in multiple ledgers
                    writeSingleEntryToMultipleLedgers(bkClient, count);
                } else {
                    System.out.println("Invalid mode. Use 1, 2, or read");
                }
            }
            
            bkClient.close();
        } catch (Exception e) {
            LOG.error("Error during BookKeeper operation", e);
        }
    }
    
    private static void writeMultipleEntriesToSingleLedger(BookKeeper bkClient, int entryCount) throws Exception {
        try (Ledger ledger = new Ledger(bkClient)) {
            LOG.info(ANSI_GREEN + "Created new ledger with ID: {}" + ANSI_RESET, ledger.getId());
            
            for (int i = 0; i < entryCount; i++) {
                String message = String.format("Entry %d - Hello BookKeeper! Account Balance: $83000", i);
                byte[] entry = message.getBytes(StandardCharsets.UTF_8);
                long entryId = ledger.write(entry);
                LOG.info(ANSI_GREEN + "Written entry {} to ledger {}" + ANSI_RESET, entryId, ledger.getId());
            }
        }
    }
    
    private static void writeSingleEntryToMultipleLedgers(BookKeeper bkClient, int ledgerCount) throws Exception {
        for (int i = 0; i < ledgerCount; i++) {
            try (Ledger ledger = new Ledger(bkClient)) {
                String message = String.format("Ledger %d - Hello BookKeeper! Account Balance: $83000", i);
                byte[] entry = message.getBytes(StandardCharsets.UTF_8);
                long entryId = ledger.write(entry);
                LOG.info(ANSI_GREEN + "Written entry to ledger {} with entryId: {}" + ANSI_RESET, ledger.getId(), entryId);
            }
        }
    }
    
    private static void readLedger(BookKeeper bkClient, long ledgerId) throws Exception {
        LOG.info(ANSI_GREEN + "Trying to read ledger with id {}" + ANSI_RESET, ledgerId);
        
        try (Ledger ledger = new Ledger(bkClient, ledgerId)) {
            Enumeration<LedgerEntry> entries = ledger.readEntries(0, ledger.getLastAddConfirmed());
            while (entries.hasMoreElements()) {
                LedgerEntry entry = entries.nextElement();
                String entryData = new String(entry.getEntry(), StandardCharsets.UTF_8);
                LOG.info(ANSI_GREEN + "Read entry {}: {}" + ANSI_RESET, entry.getEntryId(), entryData);
            }
        }
    }
}