# SMFire - TF2 Entity Debug Plugin
`sm_fire <target> <action> <value>`

At first the plugin might seem a bit complicated, because it doesn't show a list of commands for you. It's just one command with many features! So here I'll list all features currently available in SMFire.

[Preview Video](https://www.youtube.com/watch?v=EV41hXWuYRU)

(The basic.smx is not needed)

## TARGETS
#### SINGLE
- !self
- !picker
- *index
- @playername
#### MULTIPLE
- !all
- !red
- !blue
- !bots
- !select (clear/data)
- #targetname
- classname
#### SPECIAL
- !aim
- !file

## ACTIONS
- `data (full)`
- `removeslot <0-5/all>`
- `stun <duration>`
- `scare <duration>`
- `trail <R+G+B/off>`
- `respawn`
- `regen`
- `health <amount>`
- `setname <name>`
- `kill`
- `addorg <x> <y> <z>`
- `addang <pitch> <yaw> <roll>`
- `addvel <x> <y> <z>`
- `setorg <x> <y> <z>`
- `setang <pitch> <yaw> <roll>`
- `setvel <x> <y> <z>`
- `class <tfclass>`
- `setheadscale <scale>`
- `settorsoscale <scale>`
- `sethandscale <scale>`
- `resetscale`
- `fp or firstperson`
- `tp or thirdperson`
- `addcond <value>`
- `removecond <value>`
- `pitch <0-255>`
- `color <R+G+B+A> [0-255]`
- `setclip <value>`
- `noclip (on/off)`
- `freeze (on/off)`
- `teleport <target> [only single targets]`
- `copy <x> <y> <z> <pitch> <yaw> <roll>`
- `play <soundpath>`
- `wear <index>`
- `sheen <sheen index/reset> <effect index>`
- `index <item index>`
- `ks or killstreak <amount/reset>`
- `clearprops`
- `mod <index/list/reset> <value/reset>` [Attribute List](https://wiki.teamfortress.com/wiki/List_of_item_attributes)
- {tf_weapon equipping}
- {datamap manipulation}
- {all other ent_fire actions}
#### AIM
- `data (full)`
- `prop <modelpath>`
- `create <classname>`
- `value <key> <value>`
- `spawn`
- `delete`
- `copy`
- `paste`
- `shift (value) [copy placement: +speed] [value - rotation offset]`
- `move [place copy: +speed] [placement: +walk]`
- `warp (amount) [warp: W/A/S/D/JUMP/DUCK] [swap mode: +speed (Origin/Angles)]`
- `choose <filename> [placement: +speed] [cycle: +walk]`
- `select (0/range) [if no value: select/deselect: +speed]`
- `deselect (0/range) [if no value: select/deselect: +speed]`
- `decal <material_path.vmt>`
- `drop`
### FILE
- `create <filename>`
- `write <filename> <value>`
- `print <filename>`
- `delete <filename>`
- `saveprops <filename>`
- `loadprops <filename>`

## DATAMAP MANIPULATION
`sm_fire <target> <datamap> <*any>`

Gives the ability to check or change any datamap/netprop of target in-game.

[List of Datamaps](https://github.com/powerlord/tf2-data/blob/master/datamaps.txt)<br>
[List of Netprops](https://github.com/powerlord/tf2-data/blob/master/netprops.txt)

Examples:
- `m_iHealth` - player health
- `m_iClip1` - weapon clip ammo
- `m_hActiveWeapon` - players weapon currently active/holding
- `m_iName` - targetname
- `m_flMaxspeed` - max allowed speed of player

For instance, you could set the clipsize of your weapon like this:
1. `sm_fire !self h_ActiveWeapon` - gives you your active weapon entity index, lets say it's 73.
2. `sm_fire *73 m_iClip1 50` - changes that weapons clipsize to 50! (not reloadable tho)

## TF_WEAPON EQUIPPING
`sm_fire <target> <tfweapon> <index>`

Lets you equip any tf_weapon with any index. Works with multiple players!

[List of Indexes](https://wiki.alliedmods.net/Team_fortress_2_item_definition_indexes)

Examples:
- `sm_fire !self tf_weapon_rocketlauncher_directhit 127` gives directhit
- `sm_fire !self tf_weapon_knife 638` gives sharp dresser
- `sm_fire !self tf_weapon_handgun_scout_primary 457` gives you a weird one-shot Force-A-Nature?
- `sm_fire !self tf_weapon_pep_brawler_blaster 294` gives you lugermorph scattergun
