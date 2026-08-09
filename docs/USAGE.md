# Usage

## Start a server

Choose a world slot and map, then click `START SERVER`. Only one managed world can run at a time with the default shared ports.

## Save a running world

`SAVE WORLD NOW` sends `saveworld 1` through Soulmask's EchoPort. The manager verifies save activity when possible and reports failure instead of pretending the save succeeded.

## Stop safely

`STOP SERVER` performs the following sequence:

1. Sends `saveworld 1`.
2. Verifies save-database activity when possible.
3. Sends Soulmask's graceful `shutdown 5` command.
4. Waits for `WSServer.exe` to exit normally.
5. Creates a post-stop backup.

The manager intentionally does not force-kill a server after an EchoPort failure.

## Switch maps

The map selector is stored separately for each world slot:

- `CLOUD MIST FOREST` starts `Level01_Main`.
- `SHIFTING SANDS` starts `DLC_Level01_Main`.

The two maps use separate save directories. Switching the selection does not convert or delete the other map.

## Configure a world

After the world has run at least once, `CONFIGURE WORLD` can edit supported gameplay values and save per-world or all-world defaults. The manager creates configuration backups before writing changes.

## Reset a test world

`RESET TEST WORLD / NEW CHARACTER` archives the selected map save after two confirmations. It resets the entire selected map, not only one character. Gameplay settings remain in place, and the archived save is retained under `ManagerBackups`.

## Music controls

The bundled tribal-tech track starts with the manager, loops automatically, and stops when the manager closes. The slider controls volume, the button toggles mute, and the selected volume is remembered locally.

To disable the bundled track permanently, remove or rename `Soulmask-Tribal-Tech-Loop-v1.mp3` from the installed manager folder. The server controls continue to work.

