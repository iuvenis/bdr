ALTER TABLE bdr.bdr_nodes
  DROP CONSTRAINT bdr_nodes_node_status_check;

ALTER TABLE bdr.bdr_nodes
  ADD CONSTRAINT bdr_nodes_node_status_check
    CHECK (node_status in ('b', 's', 'i', 'c', 'o', 'r', 'k'));

DROP FUNCTION bdr.bdr_group_join(
    local_node_name text,
    node_external_dsn text,
    join_using_dsn text,
    node_local_dsn text,
    apply_delay integer,
    replication_sets text[]
    );

--
-- The public interface for node join/addition, to be run to join a currently
-- unconnected node with a blank database to a BDR group.
--
CREATE FUNCTION bdr.bdr_group_join(
    local_node_name text,
    node_external_dsn text,
    join_using_dsn text,
    node_local_dsn text DEFAULT NULL,
    apply_delay integer DEFAULT NULL,
    replication_sets text[] DEFAULT ARRAY['default'],
    skip_dump boolean DEFAULT false
    )
RETURNS void LANGUAGE plpgsql VOLATILE
SET search_path = bdr, pg_catalog
SET bdr.permit_unsafe_ddl_commands = on
SET bdr.skip_ddl_replication = on
SET bdr.skip_ddl_locking = on
AS $body$
DECLARE
    localid record;
    connectback_nodeinfo record;
    remoteinfo record;
BEGIN
    IF node_external_dsn IS NULL THEN
        RAISE USING
            MESSAGE = 'dsn may not be null',
            ERRCODE = 'invalid_parameter_value';
    END IF;

    IF bdr_variant() <> 'BDR' THEN
        RAISE USING
            MESSAGE = 'Full BDR required but this module is built for '||bdr_variant(),
            DETAIL = 'The local node is not running full BDR, which is required to use bdr_join',
            HINT = 'Install full BDR if possible or use the UDR functions.',
            ERRCODE = 'feature_not_supported';
    END IF;

    PERFORM bdr.internal_begin_join(
        'bdr_group_join',
        local_node_name,
        CASE WHEN node_local_dsn IS NULL THEN node_external_dsn ELSE node_local_dsn END,
        join_using_dsn,
	skip_dump);

    SELECT sysid, timeline, dboid INTO localid
    FROM bdr.bdr_get_local_nodeid();

    -- Request additional connection tests to determine that the remote is
    -- reachable for replication and non-replication mode and that the remote
    -- can connect back to us via 'dsn' on non-replication and replication
    -- modes.
    --
    -- This cannot be checked for the first node since there's no peer
    -- to ask for help.
    IF join_using_dsn IS NOT NULL THEN

        SELECT * INTO connectback_nodeinfo
        FROM bdr.bdr_test_remote_connectback(join_using_dsn, node_external_dsn);

        -- The connectback must actually match our local node identity
        -- and must provide a superuser connection.
        IF NOT connectback_nodeinfo.is_superuser THEN
            RAISE USING
                MESSAGE = 'node_external_dsn does not have superuser rights when connecting via remote node',
                DETAIL = format($$The dsn '%s' connects successfully but does not grant superuser rights$$, dsn),
                ERRCODE = 'object_not_in_prerequisite_state';
        END IF;

        IF (connectback_nodeinfo.sysid, connectback_nodeinfo.timeline, connectback_nodeinfo.dboid)
          IS DISTINCT FROM
           (localid.sysid, localid.timeline, localid.dboid)
          AND
           (connectback_nodeinfo.sysid, connectback_nodeinfo.timeline, connectback_nodeinfo.dboid)
          IS DISTINCT FROM
           (NULL, NULL, NULL) -- Returned by old versions' dummy functions
        THEN
            RAISE USING
                MESSAGE = 'node identity for node_external_dsn does not match current node when connecting back via remote',
                DETAIL = format($$The dsn '%s' connects to a node with identity (%s,%s,%s) but the local node is (%s,%s,%s)$$,
                    node_local_dsn, connectback_nodeinfo.sysid, connectback_nodeinfo.timeline,
                    connectback_nodeinfo.dboid, localid.sysid, localid.timeline, localid.dboid),
                HINT = 'The ''node_external_dsn'' parameter must refer to the node you''re running this function from, from the perspective of the node pointed to by join_using_dsn',
                ERRCODE = 'object_not_in_prerequisite_state';
        END IF;
    END IF;

    -- Null/empty checks are skipped, the underlying constraints on the table
    -- will catch that for us.
    INSERT INTO bdr.bdr_connections (
        conn_sysid, conn_timeline, conn_dboid,
        conn_origin_sysid, conn_origin_timeline, conn_origin_dboid,
        conn_dsn, conn_apply_delay, conn_replication_sets,
        conn_is_unidirectional
    ) VALUES (
        localid.sysid, localid.timeline, localid.dboid,
        '0', 0, 0,
        node_external_dsn, apply_delay, replication_sets, false
    );

    -- Now ensure the per-db worker is started if it's not already running.
    -- This won't actually take effect until commit time, it just adds a commit
    -- hook to start the worker when we commit.
    PERFORM bdr.bdr_connections_changed();
END;
$body$;

COMMENT ON FUNCTION bdr.bdr_group_join(text, text, text, text, integer, text[], boolean)
IS 'Join an existing BDR group by connecting to a member node and copying its contents';

DROP FUNCTION bdr.internal_begin_join(
    caller text, local_node_name text, node_local_dsn text, remote_dsn text,
    remote_sysid OUT text, remote_timeline OUT oid, remote_dboid OUT oid
);

-- Update join to check node status of remote during join
CREATE OR REPLACE FUNCTION bdr.internal_begin_join(
    caller text, local_node_name text, node_local_dsn text, remote_dsn text,
    remote_sysid OUT text, remote_timeline OUT oid, remote_dboid OUT oid,
    skip_dump boolean
)
RETURNS record LANGUAGE plpgsql VOLATILE
SET search_path = bdr, pg_catalog
SET bdr.permit_unsafe_ddl_commands = on
SET bdr.skip_ddl_replication = on
SET bdr.skip_ddl_locking = on
AS $body$
DECLARE
    localid RECORD;
    localid_from_dsn RECORD;
    remote_nodeinfo RECORD;
    remote_nodeinfo_r RECORD;
    cur_node RECORD;
    new_node_status text;
BEGIN
    -- Only one tx can be adding connections
    LOCK TABLE bdr.bdr_connections IN EXCLUSIVE MODE;
    LOCK TABLE bdr.bdr_nodes IN EXCLUSIVE MODE;
    LOCK TABLE pg_catalog.pg_shseclabel IN EXCLUSIVE MODE;

    SELECT sysid, timeline, dboid INTO localid
    FROM bdr.bdr_get_local_nodeid();

    -- If there's already an entry for ourselves in bdr.bdr_connections
    -- then we know this node is part of an active BDR group and cannot
    -- be joined to another group. Unidirectional connections are ignored.
    PERFORM 1 FROM bdr_connections
    WHERE conn_sysid = localid.sysid
      AND conn_timeline = localid.timeline
      AND conn_dboid = localid.dboid
      AND (conn_origin_sysid = '0'
           AND conn_origin_timeline = 0
           AND conn_origin_dboid = 0)
      AND conn_is_unidirectional = 'f';

    IF FOUND THEN
        RAISE USING
            MESSAGE = 'This node is already a member of a BDR group',
            HINT = 'Connect to the node you wish to add and run '||caller||' from it instead',
            ERRCODE = 'object_not_in_prerequisite_state';
    END IF;

    -- Validate that the local connection is usable and matches
    -- the node identity of the node we're running on.
    --
    -- For BDR this will NOT check the 'dsn' if 'node_local_dsn'
    -- gets supplied. We don't know if 'dsn' is even valid
    -- for loopback connections and can't assume it is. That'll
    -- get checked later by BDR specific code.
    --
    -- We'll get a null node name back at this point since we haven't
    -- inserted our nodes record (and it wouldn't have committed yet
    -- if we had).
    ---
    SELECT * INTO localid_from_dsn
    FROM bdr_get_remote_nodeinfo(node_local_dsn);

    IF localid_from_dsn.sysid <> localid.sysid
        OR localid_from_dsn.timeline <> localid.timeline
        OR localid_from_dsn.dboid <> localid.dboid
    THEN
        RAISE USING
            MESSAGE = 'node identity for local dsn does not match current node',
            DETAIL = format($$The dsn '%s' connects to a node with identity (%s,%s,%s) but the local node is (%s,%s,%s)$$,
                node_local_dsn, localid_from_dsn.sysid, localid_from_dsn.timeline,
                localid_from_dsn.dboid, localid.sysid, localid.timeline, localid.dboid),
            HINT = 'The node_local_dsn (or, for bdr, dsn if node_local_dsn is null) parameter must refer to the node you''re running this function from',
            ERRCODE = 'object_not_in_prerequisite_state';
    END IF;

    IF NOT localid_from_dsn.is_superuser THEN
        RAISE USING
            MESSAGE = 'local dsn does not have superuser rights',
            DETAIL = format($$The dsn '%s' connects successfully but does not grant superuser rights$$, node_local_dsn),
            ERRCODE = 'object_not_in_prerequisite_state';
    END IF;

    -- Now interrogate the remote node, if specified, and sanity
    -- check its connection too. The discovered node identity is
    -- returned if found.
    --
    -- This will error out if there are issues with the remote
    -- node.
    IF remote_dsn IS NOT NULL THEN
        SELECT * INTO remote_nodeinfo
        FROM bdr_get_remote_nodeinfo(remote_dsn);

        remote_sysid := remote_nodeinfo.sysid;
        remote_timeline := remote_nodeinfo.timeline;
        remote_dboid := remote_nodeinfo.dboid;

        IF NOT remote_nodeinfo.is_superuser THEN
            RAISE USING
                MESSAGE = 'connection to remote node does not have superuser rights',
                DETAIL = format($$The dsn '%s' connects successfully but does not grant superuser rights$$, remote_dsn),
                ERRCODE = 'object_not_in_prerequisite_state';
        END IF;

        IF remote_nodeinfo.version_num < bdr_min_remote_version_num() THEN
            RAISE USING
                MESSAGE = 'remote node''s BDR version is too old',
                DETAIL = format($$The dsn '%s' connects successfully but the remote node version %s is less than the required version %s$$,
                    remote_dsn, remote_nodeinfo.version_num, bdr_min_remote_version_num()),
                ERRCODE = 'object_not_in_prerequisite_state';
        END IF;

        IF remote_nodeinfo.min_remote_version_num > bdr_version_num() THEN
            RAISE USING
                MESSAGE = 'remote node''s BDR version is too new or this node''s version is too old',
                DETAIL = format($$The dsn '%s' connects successfully but the remote node version %s requires this node to run at least bdr %s, not the current %s$$,
                    remote_dsn, remote_nodeinfo.version_num, remote_nodeinfo.min_remote_version_num,
                    bdr_min_remote_version_num()),
                ERRCODE = 'object_not_in_prerequisite_state';

        END IF;

        IF remote_nodeinfo.node_status IS NULL THEN
            RAISE USING
                MESSAGE = 'remote node does not appear to be a fully running BDR node',
                DETAIL = format($$The dsn '%s' connects successfully but the target node has no entry in bdr.bdr_nodes$$, remote_dsn),
                ERRCODE = 'object_not_in_prerequisite_state';
        ELSIF remote_nodeinfo.node_status IS DISTINCT FROM bdr.node_status_to_char('BDR_NODE_STATUS_READY') THEN
            RAISE USING
                MESSAGE = 'remote node does not appear to be a fully running BDR node',
                DETAIL = format($$The dsn '%s' connects successfully but the target node has bdr.bdr_nodes node_status=%s instead of expected 'r'$$, remote_dsn, remote_nodeinfo.node_status),
                ERRCODE = 'object_not_in_prerequisite_state';
        END IF;

    END IF;

    -- Verify that we can make a replication connection to the remote node
    -- so that pg_hba.conf issues get caught early.
    IF remote_dsn IS NOT NULL THEN
        -- Returns (sysid, timeline, dboid) on success, else ERRORs
        SELECT * FROM bdr_test_replication_connection(remote_dsn)
        INTO remote_nodeinfo_r;

        IF (remote_nodeinfo_r.sysid, remote_nodeinfo_r.timeline, remote_nodeinfo_r.dboid)
            IS DISTINCT FROM
           (remote_sysid, remote_timeline, remote_dboid)
            AND
           (remote_sysid, remote_timeline, remote_dboid)
            IS DISTINCT FROM
           (NULL, NULL, NULL)
        THEN
            -- This just shouldn't happen, so no fancy error.
            -- The all-NULLs case only arises when we're connecting to a 0.7.x
            -- peer, where we can't get the sysid etc from SQL.
            RAISE USING
                MESSAGE = 'Replication and non-replication connections to remote node reported different node id';
        END IF;

        -- In case they're NULL because of bdr_get_remote_nodeinfo
        -- due to an old upstream
        remote_sysid := remote_nodeinfo_r.sysid;
        remote_timeline := remote_nodeinfo_r.timeline;
        remote_dboid := remote_nodeinfo_r.dboid;

    END IF;

    -- Create local node record so the apply worker knows
    -- to start initializing this node with bdr_init_replica
    -- when it's started.
    --
    -- bdr_init_copy might've created a node entry in catchup
    -- mode already, in which case we can skip this.
    SELECT node_status FROM bdr_nodes
    WHERE node_sysid = localid.sysid
      AND node_timeline = localid.timeline
      AND node_dboid = localid.dboid
    INTO cur_node;

    IF NOT FOUND THEN
        IF skip_dump THEN
	    new_node_status := 'BDR_NODE_STATUS_SYNCING_BDR_TABLES';
	ELSE
	    new_node_status := 'BDR_NODE_STATUS_BEGINNING_INIT';
	END IF;
        INSERT INTO bdr_nodes (
            node_name,
            node_sysid, node_timeline, node_dboid,
            node_status, node_local_dsn, node_init_from_dsn
        ) VALUES (
            local_node_name,
            localid.sysid, localid.timeline, localid.dboid,
            bdr.node_status_to_char(new_node_status),
            node_local_dsn, remote_dsn
        );
    ELSIF bdr.node_status_from_char(cur_node.node_status) = 'BDR_NODE_STATUS_CATCHUP' THEN
        RAISE DEBUG 'starting node join in BDR_NODE_STATUS_CATCHUP';
    ELSE
        RAISE USING
            MESSAGE = 'a bdr_nodes entry for this node already exists',
            DETAIL = format('bdr.bdr_nodes entry for (%s,%s,%s) named ''%s'' with status %s exists',
                            cur_node.node_sysid, cur_node.node_timeline, cur_node.node_dboid,
                            cur_node.node_name, bdr.node_status_from_char(cur_node.node_status)),
            ERRCODE = 'object_not_in_prerequisite_state';
    END IF;

    PERFORM bdr.internal_update_seclabel();
END;
$body$;
