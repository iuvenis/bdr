/* -------------------------------------------------------------------------
 *
 * bdr_ddlrep_deparse.c
 *      DDL deparse based DDL repliation
 *
 * DDL deparse based DDL replication is used on 9.4bdr.
 *
 * Copyright (C) 2012-2015, PostgreSQL Global Development Group
 *
 * IDENTIFICATION
 *      bdr_executor.c
 *
 * -------------------------------------------------------------------------
 */

#include "postgres.h"

#include "bdr.h"

PGDLLEXPORT Datum bdr_queue_ddl_commands(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(bdr_queue_ddl_commands);

PGDLLEXPORT Datum bdr_queue_dropped_objects(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(bdr_queue_dropped_objects);

/*
 * Deprecated functions on postgres > 9.5. Might as well remove completely, but make sure to
 * do so in extension update sql files, too
 */

Datum
bdr_queue_ddl_commands(PG_FUNCTION_ARGS)
{
	elog(ERROR, "bdr_queue_ddl_commands should not be called on postgres version > 9.5");

	PG_RETURN_VOID();
}

Datum
bdr_queue_dropped_objects(PG_FUNCTION_ARGS)
{
	elog(ERROR, "bdr_queue_dropped_objects should not be called on postgres version > 9.5");

	PG_RETURN_VOID();
}

