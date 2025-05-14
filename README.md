# Warden [![Sourcemod CI](https://github.com/notfoundname/Warden/actions/workflows/sourcemod.yml/badge.svg)](https://github.com/notfoundname/Warden/actions/workflows/sourcemod.yml)
Sourcemod plugin for Counter-Strike: Source for jailbreak servers.
Made to work alongside SM Hosties, but is independent.

# Credits
Originally made by ecca, editied by notfoundname.
Looked up a lot of stuff from [destoer's plugin](https://github.com/destoer/counter_strike_jailbreak) and [ByDexter's PR](https://github.com/ecca/SourceMod-Plugins/pull/3/).

# Features
- Warden with menu
- Noblock toggle
- Temp mute toggle
- Friendly fire toggle
- Splitting players into two teams
- Admin commands
- Translations (en, ru) with colours support
- todo: laserbeam

# ConVars
| Name | Default Value | Value Type | Description |
|---|---|---|---|
| `sm_warden_version` | `PLUGIN_VERSION` | `String` | The version of the SourceMod plugin JailBreak Warden. |
| `sm_warden_better_notifications` | `1` | `bool` | 0 - disabled, 1 - Will display center text. |
| `sm_warden_mute_time` | `20` | `float` | For how long warden can mute players. |
| `sm_warden_noblock_default` | `1` | `bool` | 0 - start with player collisions, 1 - start with no collisions. |
| `sm_warden_splitplayers_radius` | `256` | `float` | Radius of searching for splitting players into two teams. 0 to not care. |

# Commands
| Name | Arguments | Permission | Description |
|---|---|---|---|
| `sm_w` | - | Alive Counter-Terrorist | Become warden. |
| `sm_uw` | - | Alive Counter-Terrorist | Retire as a warden. |
| `sm_wnb` | - | Warden | Toggle collisions between players. |
| `sm_wm` | - | Warden | Temporary mute terrorists. |
| `sm_wff` | - | Warden | Toggle friendly fire. |
| `sm_wsp` | - | Warden | Split players into two teams. |
| `sm_hw` | `<#userid\|name>` | Admins | Force the player to become warden. |
| `sm_rw` | - | Admins | Force the warden to retire. |
