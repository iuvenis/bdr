CREATE TABLE test_tbl_simple_create(val int);
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_simple_create
\c postgres
\d+ test_tbl_simple_create

DROP TABLE test_tbl_simple_create;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_simple_create
\c regression
\d+ test_tbl_simple_create

CREATE UNLOGGED TABLE test_tbl_unlogged_create(val int);
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_unlogged_create
\c postgres
-- Should not exist because unlogged tables are excluded from replication
\d+ test_tbl_unlogged_create

\c regression
DROP TABLE test_tbl_unlogged_create;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_unlogged_create

CREATE TABLE test_tbl_simple_pk(val int PRIMARY KEY);
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_simple_pk
\c postgres
\d+ test_tbl_simple_pk

DROP TABLE test_tbl_simple_pk;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_simple_pk
\c regression
\d+ test_tbl_simple_pk

CREATE TABLE test_tbl_combined_pk(val int, val1 int, PRIMARY KEY (val, val1));
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_combined_pk
\c postgres
\d+ test_tbl_combined_pk

DROP TABLE test_tbl_combined_pk;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_combined_pk
\c regression
\d+ test_tbl_combined_pk

CREATE TABLE test_tbl_serial(val SERIAL);
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_serial
\c postgres
\d+ test_tbl_serial

DROP TABLE test_tbl_serial;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_serial
\c regression
\d+ test_tbl_serial

CREATE TABLE test_tbl_serial(val SERIAL);
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_serial
\c postgres
\d+ test_tbl_serial

CREATE TABLE test_tbl_serial_pk(val SERIAL PRIMARY KEY);
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_serial_pk
\c postgres
\d+ test_tbl_serial_pk

DROP TABLE test_tbl_serial_pk;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_serial_pk
\c regression
\d+ test_tbl_serial_pk

CREATE TABLE test_tbl_serial_combined_pk(val SERIAL, val1 INTEGER, PRIMARY KEY (val, val1));
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_serial_combined_pk
\c postgres
\d+ test_tbl_serial_combined_pk

CREATE TABLE test_tbl_create_index (val int, val2 int);
CREATE UNIQUE INDEX test1_idx ON test_tbl_create_index(val);
CREATE INDEX test2_idx ON test_tbl_create_index (lower(val2::text));
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_create_index
\c regression
\d+ test_tbl_create_index

DROP INDEX test1_idx;
DROP INDEX test2_idx;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_create_index
\c postgres
\d+ test_tbl_create_index

CREATE INDEX test1_idx ON test_tbl_create_index(val, val2);
CREATE INDEX test2_idx ON test_tbl_create_index USING gist (val, UPPER(val2::text));
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_create_index
\c regression
\d+ test_tbl_create_index

DROP INDEX test1_idx;
-- Should fail because BDR2 does not support concurrent index operations
DROP INDEX CONCURRENTLY test2_idx;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_create_index
\c postgres
\d+ test_tbl_create_index

-- Should both fail because BDR2 does not support concurrent index operations
CREATE INDEX CONCURRENTLY test1_idx ON test_tbl_create_index(val, val2);
CREATE UNIQUE INDEX CONCURRENTLY test2_idx ON test_tbl_create_index (lower(val2::text));
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_create_index
\c regression
\d+ test_tbl_create_index

-- Should both fail because BDR2 does not support concurrent index operations
DROP INDEX CONCURRENTLY test1_idx;
DROP INDEX CONCURRENTLY test2_idx;
DROP TABLE test_tbl_create_index;

CREATE TABLE test_simple_create_with_arrays_tbl(val int[], val1 text[]);
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_simple_create_with_arrays_tbl
\c postgres
\d+ test_simple_create_with_arrays_tbl

DROP TABLE test_simple_create_with_arrays_tbl;

CREATE TYPE test_t AS ENUM('a','b','c');
CREATE TABLE test_simple_create_with_enums_tbl(val test_t, val1 test_t);
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_simple_create_with_enums_tbl
\c regression
\d+ test_simple_create_with_enums_tbl

DROP TABLE test_simple_create_with_enums_tbl;
DROP TYPE test_t;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_simple_create_with_enums_tbl

\dT+ test_t
\c postgres
\d+ test_simple_create_with_enums_tbl

\dT+ test_t

CREATE TYPE test_t AS (f1 text, f2 float, f3 integer);
CREATE TABLE test_simple_create_with_composites_tbl(val test_t, val1 test_t);
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_simple_create_with_composites_tbl
\c regression
\d+ test_simple_create_with_composites_tbl

DROP TABLE test_simple_create_with_composites_tbl;
DROP TYPE test_t;
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_simple_create_with_composites_tbl

\dT+ test_t
\c postgres
\d+ test_simple_create_with_composites_tbl

\dT+ test_t

DROP TABLE test_tbl_serial;
DROP TABLE test_tbl_serial_combined_pk;

CREATE TABLE test_tbl_inh_parent(f1 text, f2 date DEFAULT '2014-01-02');
CREATE TABLE test_tbl_inh_chld1(f1 text, f2 date DEFAULT '2014-01-02') INHERITS (test_tbl_inh_parent);
CREATE TABLE test_tbl_inh_chld2(f1 text, f2 date) INHERITS (test_tbl_inh_parent);
CREATE TABLE test_tbl_inh_chld3(f1 text) INHERITS (test_tbl_inh_parent, test_tbl_inh_chld1);

SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_inh_*
\c regression
\d+ test_tbl_inh_*

CREATE RULE test_tbl_inh_parent_rule_ins_1 AS ON INSERT TO test_tbl_inh_parent
          WHERE (f1 LIKE '%1%') DO INSTEAD
          INSERT INTO test_tbl_inh_chld1 VALUES (NEW.*);
CREATE RULE test_tbl_inh_parent_rule_ins_2 AS ON INSERT TO test_tbl_inh_parent
          WHERE (f1 LIKE '%2%') DO INSTEAD
          INSERT INTO test_tbl_inh_chld2 VALUES (NEW.*);

SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_inh_parent
\c postgres
\d+ test_tbl_inh_parent

DROP TABLE test_tbl_inh_chld1;
DROP TABLE test_tbl_inh_parent CASCADE;

SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\d+ test_tbl_inh_*
\c regression
\d+ test_tbl_inh_*

-- ensure storage attributes in CREATE TABLE are replicated properly
\c postgres
CREATE TABLE tbl_showfillfactor (name char(500), unique (name) with (fillfactor=65)) with (fillfactor=75);
\d+ tbl_showfillfactor
SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\c regression
\d+ tbl_showfillfactor
DROP TABLE tbl_showfillfactor;

--- AGGREGATE ---
\c postgres

CREATE AGGREGATE test_avg (
   sfunc = int4_avg_accum, basetype = int4, stype = _int8,
   finalfunc = int8_avg,
   initcond1 = '{0,0}',
   sortop = =
);

-- without finalfunc; test obsolete spellings 'sfunc1' etc
CREATE AGGREGATE test_sum (
   sfunc1 = int4pl, basetype = int4, stype1 = int4,
   initcond1 = '0'
);

-- zero-argument aggregate
CREATE AGGREGATE test_cnt (*) (
   sfunc = int8inc, stype = int8,
   initcond = '0'
);

SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\dfa test_*
\c regression
\dfa test_*

DROP AGGREGATE test_avg(int4);
DROP AGGREGATE test_sum(int4);
DROP AGGREGATE test_cnt(*);

SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\dfa test_*
\c postgres
\dfa test_*

create type aggtype as (a integer, b integer, c text);

create function aggf_trans(aggtype[],integer,integer,text) returns aggtype[]
as 'select array_append($1,ROW($2,$3,$4)::aggtype)'
language sql strict immutable;

create function aggfns_trans(aggtype[],integer,integer,text) returns aggtype[]
as 'select array_append($1,ROW($2,$3,$4)::aggtype)'
language sql immutable;

create aggregate test_aggfstr(integer,integer,text) (
   sfunc = aggf_trans, stype = aggtype[],
   initcond = '{}'
);

SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\dfa test_*
\c regression
\dfa test_*

DROP AGGREGATE test_aggfstr(integer,integer,text);
DROP FUNCTION aggf_trans(aggtype[],integer,integer,text);
DROP FUNCTION aggfns_trans(aggtype[],integer,integer,text);
DROP TYPE aggtype;

SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\dfa test_*
\c postgres
\dfa test_*

--- OPERATOR ---
\c postgres

CREATE OPERATOR ## (
   leftarg = path,
   rightarg = path,
   procedure = path_inter,
   commutator = ##
);

CREATE OPERATOR @#@ (
   rightarg = int8,		-- left unary
   procedure = factorial
);

SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\do public.##
\do public.@#@
\c regression
\do public.##
\do public.@#@

DROP OPERATOR ##(path, path);
DROP OPERATOR @#@(none,int8);

\do public.##
\do public.@#@

SELECT bdr.wait_slot_confirm_lsn(NULL,NULL);
\c postgres
\do public.##
\do public.@#@
