# Bank

Bank is a lightweight banking system for CC:Tweaked, designed for Minecraft 1.21.1.

## Programs

| File | Purpose |
| --- | --- |
| `bank_server.lua` | Runs on the central computer and processes registrations, balance checks and transfers. |
| `bank_pocket.lua` | Client application for an Advanced Pocket Computer. |
| `bank_admin.lua` | Looks up accounts, adjusts balances, blocks accounts and displays transaction history and statistics. |
| `bank_init.lua` | Creates the database directory and initial files without replacing existing data. |
| `bank_check.lua` | Displays connected peripherals and modem information. |
| `bank_net_test.lua` | Tests the Rednet connection between computers 203 and 204. |

## Setup

1. Run `bank_init.lua` once on the central computer.
2. Start `bank_server.lua` on computer 203.
3. Download and run `bank_pocket.lua` on an Advanced Pocket Computer.
4. Leave the server running while clients use the bank.

The Pocket client sends requests over the Rednet protocol named `bank`. Its server computer ID is configured as `203`.

## Stored data

Account records, transaction history and bank settings are stored in the `bank_data` directory. The initialization program leaves existing database files untouched.

## Security

This is a server-side Minecraft prototype, not a real banking system. PINs are stored as plain text, network traffic is not encrypted, and the administrator program has no authentication. Do not use real passwords or sensitive credentials with it.
