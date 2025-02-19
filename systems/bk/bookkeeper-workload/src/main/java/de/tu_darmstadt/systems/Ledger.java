package de.tu_darmstadt.systems;

import org.apache.bookkeeper.client.BKException;
import org.apache.bookkeeper.client.BookKeeper;
import org.apache.bookkeeper.client.LedgerEntry;
import org.apache.bookkeeper.client.LedgerHandle;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.Closeable;
import java.util.Enumeration;

public class Ledger implements Closeable {

    public static final int ENSEMBLE_SIZE = 1;
    public static final int QUORUM_SIZE_ACK = 1;
    public static final int QUORUM_SIZE_WRITE = 1;

    private static final Logger LOG = LoggerFactory.getLogger(Ledger.class);
    private final LedgerHandle handle;

    public Ledger(BookKeeper bkClient) throws BKException, InterruptedException {
        handle = bkClient.createLedger(
            ENSEMBLE_SIZE,
            QUORUM_SIZE_WRITE,
            QUORUM_SIZE_ACK,
            BookKeeper.DigestType.MAC,
            "some-password".getBytes()
        );
        LOG.info("Created ledger with id={}", handle.getId());
    }

    public Ledger(BookKeeper bkClient, long ledgerId) throws BKException, InterruptedException {
        handle = bkClient.openLedger(
            ledgerId,
            BookKeeper.DigestType.MAC,
            "some-password".getBytes()
        );
        LOG.info("Opened ledger with id={}", handle.getId());
    }

    public long write(byte[] payload) throws BKException, InterruptedException {
        long entryId = handle.addEntry(payload);
        LOG.debug("Written entry with id={}", entryId);
        return entryId;
    }

    public Enumeration<LedgerEntry> readEntries(long firstEntryId, long lastEntryId) throws BKException, InterruptedException {
        return handle.readEntries(firstEntryId, lastEntryId);
    }

    public long getId() {
        return handle.getId();
    }

    public long getLastAddConfirmed() {
        return handle.getLastAddConfirmed();
    }

    @Override
    public void close() {
        try {
            handle.close();
        } catch (InterruptedException | BKException e) {
            LOG.error("Error closing ledger", e);
        }
    }
}