-- 000_init.sql
-- Baseline migration: ensure the migrations ledger table exists and
-- create a single test table to verify the connection works end-to-end.

CREATE TABLE IF NOT EXISTS users_test (
  id         SERIAL PRIMARY KEY,
  email      TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);