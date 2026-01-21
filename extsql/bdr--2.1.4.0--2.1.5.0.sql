--
-- This is a helper for node_join, for internal use only. It's called
-- on the remote end by the init code when joining an existing group,
-- to do the remote-side setup.
--
CREATE OR REPLACE FUNCTION bdr.internal_node_join(
    sysid text, timeline oid, dboid oid,
    node_external_dsn text,
    apply_delay integer,
    replication_sets text[]
    )
RETURNS void LANGUAGE plpgsql VOLATILE
SET search_path = bdr, pg_catalog
AS
$body$
BEGIN
    LOCK TABLE bdr.bdr_connections IN EXCLUSIVE MODE;
    LOCK TABLE pg_catalog.pg_shseclabel IN EXCLUSIVE MODE;

    IF bdr_variant() <> 'BDR' THEN
        RAISE USING
            MESSAGE = 'Full BDR required but this module is built for '||bdr_variant(),
            DETAIL = 'The target node is running something other than full BDR so you cannot join a BDR node to it',
            HINT = 'Install full BDR if possible or use the UDR functions.',
            ERRCODE = 'feature_not_supported';
    END IF;

    IF NOT EXISTS(SELECT node_sysid FROM bdr.bdr_nodes
                    WHERE node_sysid = sysid AND node_timeline = timeline AND node_dboid = dboid) THEN
       RAISE object_not_in_prerequisite_state
              USING MESSAGE = format('bdr.bdr_nodes entry for (%s,%s,%s) not found',
                                     sysid, timeline, dboid);
    END IF;

    -- Insert or Update the connection info on this node, which we must be
    -- initing from.
    -- No need to care about concurrency here as we hold EXCLUSIVE LOCK.
    BEGIN
        INSERT INTO bdr.bdr_connections
        (conn_sysid, conn_timeline, conn_dboid,
         conn_origin_sysid, conn_origin_timeline, conn_origin_dboid,
         conn_dsn,
         conn_apply_delay, conn_replication_sets,
         conn_is_unidirectional)
        VALUES
        (sysid, timeline, dboid,
         '0', 0, 0,
         node_external_dsn,
         CASE WHEN apply_delay = -1 THEN NULL ELSE apply_delay END,
         replication_sets, false);
    EXCEPTION WHEN unique_violation THEN
        UPDATE bdr.bdr_connections
        SET conn_dsn = node_external_dsn,
            conn_apply_delay = CASE WHEN apply_delay = -1 THEN NULL ELSE apply_delay END,
            conn_replication_sets = replication_sets,
            conn_is_unidirectional = false
        WHERE conn_sysid = sysid
          AND conn_timeline = timeline
          AND conn_dboid = dboid
          AND conn_origin_sysid = '0'
          AND conn_origin_timeline = 0
          AND conn_origin_dboid = 0;
    END;

    -- Schedule the apply worker launch for commit time
    PERFORM bdr.bdr_connections_changed();

    -- and ensure the apply worker is launched on other nodes
    -- when this transaction replicates there, too.
    INSERT INTO bdr.bdr_queued_commands
    (lsn, queued_at, perpetrator, command_tag, command)
    VALUES
    (pg_current_wal_insert_lsn(), current_timestamp, current_user,
    'SELECT', 'SELECT bdr.bdr_connections_changed()');
END;
$body$;

