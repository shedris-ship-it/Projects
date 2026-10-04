# Example mansions

Printed with `lune run tools/plan <seed> mansion` (2026-10-04, phase M1). Each 10-stud lattice step is 4 characters wide and 2 rows tall; north is up and the front of the house is at the bottom. The grand hall and stairwells are dotted because they stand on both floors.

How to read them:
- `D` is a doorway with a door, a gap is an open doorway, and `:` is a solid wall shared with the next room (a Phantom Architecture doorway can appear there).
- `F` is the front door, which shuts behind the squad; `X` is the exit.
- Room labels are the id and the start of the template name. `S` marks the start, `E` the exit, `T` the Deliberation Table, `L` a Lantern room.

What to look for: the hall at the front; the service wing (dining room, kitchen, service passage, back stairs, exit at the rear) on one side; public rooms and corridors on the other; bedrooms upstairs; and the loop between the floors through the back stairs.

## Seed 1800820264

The debug seed the screenshots use (`seed 1800820264` in the F2 console).

```text
Ground floor
+--XXX--+
|6mudr  |
|E      |-------+-----------+
|       |4serv  |5back .   .|
|               D .   .   . |
|       |       |.   .   .  |
+-------+       +-----------+               +---------------+
        |       |                           |12livi         |
        +--   --+---+           +-----------|               |
        |3kitc      |           |10musi     |               |
        |           |-----------|                           |
        |           |2dini      |           |               |
        |           DT          :           +------DDD--+-------+
        |           |           |           |   |11stud |13den  |
        +-----------+           +--DDD------+---|               |
                    |           |1gran .   .   .|       |       |
                    |           DS.   .   .   . D       |       |
                    |           |.   .   .   .  |       |       |
                    +-----------+   .   .   .   +--:::--+--DDD--+-----------+
                                |  .   .   .   .|7main          |14sunr     |
                                | .   .   .   . D               D           |
                                |.   .   .   .  |               |           |
                                |   .   .   .   +---------------|           |
                                |  .   .   .   .|               |           |
                                +------FFF------+               +-----------+

Upper floor
+-------+
|19bath |
|       |-------+-----------+
|       |8uppe  |5back .   .|
|       D       D .   .   . |
|       |       |.   .   .  |
+-------+       |-----------+
        |       |
        +--DDD--+
        |16uppe |
        |       |-----------------------+
        |       |15uppe                 |
        |       D                       |       +-----------+
        |       |                       |       |18mast     |
        +-------+---+--   ------+--   --+-------|           |
                    |17sewi     |1gran .   .   .|           |
                    |           :S.   .   .   . :           |
                    |           |.   .   .   .  |           |
                    +-----------+   .   .   .   +--DDD------+---+
                                |  .   .   .   .|9uppe          |
                                | .   .   .   . DL              |
                                |.   .   .   .  |               |
                                |   .   .   .   +---------------+
                                |  .   .   .   .|
                                +---------------+

Legend: D door, gap open doorway, : solid seam, F front door, X exit; S start, E exit, T table, L lantern
   1 grand_hall       40x50 floor 0+1 hall rot 0 start
   2 dining_room      30x40 floor 0 dining rot 1 deliberation
   3 kitchen          30x30 floor 0 kitchen rot 0 
   4 service_corridor 20x30 floor 0 service rot 0 
   5 back_stairs      30x20 floor 0+1 service rot 3 
   6 mudroom          20x30 floor 0 service rot 0 exit
   7 main_corridor    40x20 floor 0 public rot 0 
   8 upper_corridor   20x30 floor 1 private rot 0 
   9 upper_corridor   40x20 floor 1 private rot 0  lantern
  10 music_room       30x30 floor 0 public rot 2 
  11 study            20x30 floor 0 public rot 1 
  12 living_room      40x30 floor 0 public rot 2 
  13 den              20x30 floor 0 public rot 1 
  14 sunroom          30x30 floor 0 public rot 2 
  15 upper_corridor   60x20 floor 1 private rot 0 
  16 upper_corridor   20x30 floor 1 private rot 0 
  17 sewing_room      30x20 floor 1 private rot 0 
  18 master_bedroom   30x30 floor 1 private rot 0 
  19 bathroom         20x30 floor 1 bath rot 1 
seed 1800820264, 19 rooms, attempts 1, hash 677040433
```

## Seed 61

The authored fallback (`Data/MansionFallback`), used when every attempt fails. It has two stairwells: the back stairs and a second one at the end of the rear corridor.

```text
Ground floor
                    +-------+       +--XXX--+-------+-----------+
                    |11stai |       |6mudr  |4serv  |5back   .  |
                    |   .   |       |E      D       D   .   .   |
                    |  .   .|       |       |       |  .   .   .|
                    | .   . |       |       |       +-----------+
                    |.   .  |       |       |       |
                    +--DDD--+-----------+---+       |
                    |8main  |12bath     |   |       |
        +-----------+                   |   |       |
        |15stud     |       |           |   |       |
        |           D       +--:::------+---+--DDD--+
        |           |       |13musi     |3kitc      |
        +--:::------+                   :           |
        |14livi     |       |           |           |
        |           D       |           |           |
        |           |       |           |           |
        |           |--   --+--:::------+--   ------+
        |           |1gran   .   .  |2dini          |
        |           :S  .   .   .   DT              |
        |           |  .   .   .   .|               |
+-------+--DDD------+ .   .   .   . |               |
|16den  |7main      |.   .   .   .  |               |
|       D               .   .   .   +---------------+
|       |           |  .   .   .   .|
|       |-----------+ .   .   .   . |
|       |           |.   .   .   .  |
+-------+           +------FFF------+

Upper floor
                    +-------+       +-------+-------+-----------+
                    |11stai |       |20gues |9uppe  |5back   .  |
                    |   .   |       |       D       D   .   .   |
                    |  .   .|       |       |       |  .   .   .|
                    | .   . |       |       |       |-----------+
                    |.   .  |       |       |       |
                    +--   --+-----------+---+       |
                    |10uppe |21bath     |   |       |
                    |       D           |   |       |
                    |       |           |   |       |
                    |       +--:::------+------   --+
                    |       |17uppe                 |
        +-----------+       D                       |
        |19mast     |       |                       |
        |L          D       +-------+--DDD------+---+
        |           |       |       |18kids     |
        |           |--   --+-------|L          |
        |           |1gran   .   .  |           |
        +-----------+S  .   .   .   D           |
                    |  .   .   .   .|           |
                    | .   .   .   . +-----------+
                    |.   .   .   .  |
                    |   .   .   .   |
                    |  .   .   .   .|
                    | .   .   .   . |
                    |.   .   .   .  |
                    +---------------+

Legend: D door, gap open doorway, : solid seam, F front door, X exit; S start, E exit, T table, L lantern
   1 grand_hall       40x50 floor 0+1 hall rot 0 start
   2 dining_room      40x30 floor 0 dining rot 0 deliberation
   3 kitchen          30x30 floor 0 kitchen rot 1 
   4 service_corridor 20x50 floor 0 service rot 0 
   5 back_stairs      30x20 floor 0+1 service rot 3 
   6 mudroom          20x30 floor 0 service rot 0 exit
   7 main_corridor    30x20 floor 0 public rot 0 
   8 main_corridor    20x50 floor 0 public rot 0 
   9 upper_corridor   20x50 floor 1 private rot 0 
  10 upper_corridor   20x50 floor 1 private rot 0 
  11 stairwell        20x30 floor 0+1 public rot 0 
  12 bathroom         30x20 floor 0 bath rot 2 
  13 music_room       30x30 floor 0 public rot 2 
  14 living_room      30x40 floor 0 public rot 3 
  15 study            30x20 floor 0 public rot 2 
  16 den              20x30 floor 0 public rot 1 
  17 upper_corridor   60x20 floor 1 private rot 0 
  18 kids_bedroom     30x30 floor 1 private rot 2  lantern
  19 master_bedroom   30x30 floor 1 private rot 2  lantern
  20 guest_room       20x30 floor 1 private rot 2 
  21 bathroom         30x20 floor 1 bath rot 0 
seed 61, 21 rooms, attempts 1, hash 5431999
```

## Seed 7

A garage exit, and a single stairwell.

```text
Ground floor
    +-------+
    |5back  |
    |   .   +------XXX------+               +-----------+
    |  .   .|6gara          |               |12musi     |
    | .   . |E              |       +-------|           |
    |.   .  |               |       |10stud |           |
+---+--DDD--|               |       |                   |
|4serv      |               |       |       |           |
|           D               |       |       +--DDD------+
|           |               |       |       |9livi      |
+------   --+---------------+-------+--DDD--+           |
    |3kitc      |           |1gran .   .   .|           |
    |           |-----------+S.   .   .   . :           +-----------+
    |           |2dini      |.   .   .   .  |           |11bath     |
    |           DT          |   .   .   .   |           :           |
    |           |           |  .   .   .   .|           |           |
    +---+--:::--+           D .   .   .   . +--   ------+--   ------+
        |13pant |           |.   .   .   .  |7main                  |
        |       D           |   .   .   .                           |
        |       |           |  .   .   .   .|                       |
        +-------+-----------+------FFF------+-----------------------+

Upper floor
    +-------+
    |5back  |
    |   .   |
    |  .   .|
    | .   . +-------+
    |.   .  |17play |
+------DDD--|       |               +-----------+
|8uppe      |       |               |18gues     |
|                   |               |           |
|           |       |               |           |
+---+--   --+-------+       +-------+--   --+-----------+
    |15uppe |               |1gran .   .   .|19kids     |
    |       |---------------+S.   .   .   .  L          |
    |       |14uppe         |.   .   .   .  |           |
    |       D               D   .   .   .   |           |
    |       |               |  .   .   .   .|           |
    +-------+--DDD------+---+ .   .   .   . +-----------+
            |16sewi     |   |.   .   .   .  |
            |           |   |   .   .   .   |
            |           |   |  .   .   .   .|
            +-----------+   +---------------+

Legend: D door, gap open doorway, : solid seam, F front door, X exit; S start, E exit, T table, L lantern
   1 grand_hall       40x50 floor 0+1 hall rot 0 start
   2 dining_room      30x40 floor 0 dining rot 1 deliberation
   3 kitchen          30x30 floor 0 kitchen rot 0 
   4 service_corridor 30x20 floor 0 service rot 0 
   5 back_stairs      20x30 floor 0+1 service rot 0 
   6 garage           40x40 floor 0 service rot 1 exit
   7 main_corridor    60x20 floor 0 public rot 0 
   8 upper_corridor   30x20 floor 1 private rot 0 
   9 living_room      30x40 floor 0 public rot 1 
  10 study            20x30 floor 0 public rot 1 
  11 bathroom         30x20 floor 0 bath rot 2 
  12 music_room       30x30 floor 0 public rot 1 
  13 pantry           20x20 floor 0 kitchen rot 0 
  14 upper_corridor   40x20 floor 1 private rot 0 
  15 upper_corridor   20x30 floor 1 private rot 0 
  16 sewing_room      30x20 floor 1 private rot 2 
  17 playroom         20x30 floor 1 private rot 3 
  18 guest_room       30x20 floor 1 private rot 1 
  19 kids_bedroom     30x30 floor 1 private rot 2  lantern
seed 7, 19 rooms, attempts 1, hash 1709403357
```
