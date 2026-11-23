# Bank

A small banking system for CC:Tweaked on Minecraft 1.21.1.

## Programs

- `bank_server.lua` runs on the central computer and handles account registration, balance checks and transfers.
- `bank_pocket.lua` is the Pocket Computer client.
- `bank_admin.lua` provides account lookup, balance adjustments, account blocking, transaction history and basic statistics.
- `bank_init.lua` creates the database files without overwriting existing data.
- `bank_migrate_ids.lua` is a one-time utility for migrating account IDs. Do not run it again after migration has completed.
- `bank_check.lua` lists connected peripherals and modem details.
- `bank_net_test.lua` checks the Rednet connection between computers 203 and 204.
- `bank_test_client.lua` is a simple registration and balance test client.

## Setup

1. Run `bank_init.lua` once on the central computer.
2. Start `bank_server.lua` on computer 203.
3. Download and run `bank_pocket.lua` on an Advanced Pocket Computer.
4. Keep the server running while clients use the bank.

The server and Pocket client use the Rednet protocol `bank`. The server computer ID is set to 203 in the Pocket client.

## Data

The server stores account records, transaction history and settings in the `bank_data` directory. The initialization program preserves existing database files.

This project is a Minecraft server-side prototype. It stores PINs without encryption and does not provide network encryption or administrator authentication. Do not use it for real money or sensitive credentials.
