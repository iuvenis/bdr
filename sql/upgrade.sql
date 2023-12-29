/*
 * Test extension create/update/drop for each supported version. Should
 * probably be maintained automatedly at some point.
 */
CREATE DATABASE extension_upgrade;
\c extension_upgrade

-- Create prerequisite extensions
CREATE EXTENSION btree_gist;

-- create each version of the extension directly
CREATE EXTENSION bdr VERSION '1.0.0.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '1.0.1.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '1.0.2.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '1.0.3.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '2.0.0.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '2.0.1.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '2.0.2.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '2.0.3.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '2.0.4.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '2.0.5.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '2.0.6.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '2.0.7.0';
DROP EXTENSION bdr;
CREATE EXTENSION bdr VERSION '2.1.0.0';
DROP EXTENSION bdr;

-- evolve version one by one from the oldest to the newest one
CREATE EXTENSION bdr VERSION '1.0.0.0';
ALTER EXTENSION bdr UPDATE TO '1.0.1.0';
ALTER EXTENSION bdr UPDATE TO '1.0.2.0';
ALTER EXTENSION bdr UPDATE TO '1.0.3.0';
ALTER EXTENSION bdr UPDATE TO '2.0.0.0';
ALTER EXTENSION bdr UPDATE TO '2.0.1.0';
ALTER EXTENSION bdr UPDATE TO '2.0.2.0';
ALTER EXTENSION bdr UPDATE TO '2.0.3.0';
ALTER EXTENSION bdr UPDATE TO '2.0.4.0';
ALTER EXTENSION bdr UPDATE TO '2.0.5.0';
ALTER EXTENSION bdr UPDATE TO '2.0.6.0';
ALTER EXTENSION bdr UPDATE TO '2.0.7.0';
ALTER EXTENSION bdr UPDATE TO '2.1.0.0';

-- Should never have to do anything: You missed adding the new version above.
ALTER EXTENSION bdr UPDATE;

\dx bdr

\c postgres
DROP DATABASE extension_upgrade;
