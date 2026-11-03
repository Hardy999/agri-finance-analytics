-- Creates the project database, only if it does not already exist.
-- DB_ID() returns NULL when no database has that name, so running this
-- twice is harmless: the second run does nothing.
IF DB_ID('AgriFinance') IS NULL
    CREATE DATABASE AgriFinance;
GO