# SMFire - TF2 Entity Debug Plugin
`sm_fire <target> <action> <value>`

At first the plugin might seem a bit complicated, because it doesn't show a list of commands for you. It's just one command with many features! So here I'll list all features currently available in SMFire.
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
- #targetname
- classname
#### SPECIAL
- !aim

## ACTIONS
#### SINGLE
- copy `<x> <y> <z> <pitch> <yaw> <roll>`
- teleport `<target>`
- {datamap manipulation}
#### SINGLE + MULTIPLE
- data `*full`
- removeslot `<0-5>`
- stun `<duration>`
- setname `<name>`
- kill
- addorg `<x> <y> <z>`
- addang `<pitch> <yaw> <roll>`
- setorg `<x> <y> <z>`
- setang `<pitch> <yaw> <roll>`
- class `<tfclass>`
- setheadscale `<scale>`
- settorsoscale `<scale>`
- sethandscale `<scale>`
- resetscale
- fp or firstperson
- tp or thirdperson
- addcond `<value>`
- removecond `<value>`
- pitch `<0-255>`
- color `<R+G+B+A> [0-255]`
- {all other ent_fire actions}
#### ONLY SPECIAL
- data `*full`
- prop `<modelpath>`
- create `<classname>`
- value `<key> <value>`
- spawn 
- delete
- copy
- paste
- shift `*0-360`

## DATAMAP MANIPULATION
If the action contains "m_" it will automatically be recognized as a datamap if it is a valid one and you can set different values for it in-game.

#### EXAMPLES
sm_fire !self m_iHealth 541
- sets clients health to 541.

sm_fire @jake m_hActiveWeapon
- shows client jake's active weapon entity index

sm_fire *73 m_iClip1 57
- sets the clipsize of entity with index 73 to 57.
