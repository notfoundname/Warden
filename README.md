# Warden
Sourcemod plugin for Counter-Strike: Source for jailbreak servers

# Features
- Warden
- Noblock
- Temp mute
- Admin commands
- Translations (en, ru) with colours support

# ConVars
| Name | Default Value | Value Type | Description |
|:---:|:---:|:---:|---|
| `sm_warden_version` | `PLUGIN_VERSION` | `String` | The version of the SourceMod plugin JailBreak Warden, by ecca & notfoundname. |
| `sm_warden_better_notifications` | `1` | `int` | 0 - disabled, 1 - Will display center text. |
| `sm_warden_mute_time` | `20` | `int` | For how long warden can mute players. |
| `sm_warden_noblock_default` | `1` | `bool` | 0 - start with player collisions, 1 - start with no collisions. |

# Commands
| Name | Arguments | Permission | Description |
|:---:|:---:|:---:|---|
| `sm_w` | - | Alive Counter-Terrorist | Become warden. |
| `sm_uw` | - | Alive Counter-Terrorist | Retire as a warden. |
| `sm_wnb` | - | Warden | Toggle collisions between players. |
| `sm_wm` | - | Warden | Temporary mute terrorists. |
| `sm_wff` | - | Warden | Toggle friendly fire. |
| `sm_hw` | `<#userid\|name>` | Admins | Force the player to become warden. |
| `sm_rw` | - | Admins | Force the warden to retire. |

# Credits
Originally made by ecca, editied by notfoundname.
Looked up a lot of stuff from [destoer's plugin](https://github.com/destoer/counter_strike_jailbreak).