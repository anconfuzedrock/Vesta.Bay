/obj/structure/table/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if(air_group || (height==0)) return 1
	if(istype(mover,/obj/item/projectile))
		return (check_cover(mover,target))
	if (flipped == 1)
		if (get_dir(loc, target) == dir)
			return !density
		else
			return 1
	if(istype(mover) && mover.checkpass(PASS_FLAG_TABLE))
		return 1
	var/obj/structure/table/T = (locate() in get_turf(mover))
	return (T && !T.flipped) 	//If we are moving from a table, check if it is flipped.
								//If the table we are standing on is not flipped, then we can move freely to another table.


//checks if projectile 'P' from turf 'from' can hit whatever is behind the table. Returns 1 if it can, 0 if bullet stops.
/obj/structure/table/proc/check_cover(obj/item/projectile/P, turf/from)
	var/turf/cover
	if(flipped)
		cover = get_turf(src)
	else
		cover = get_step(loc, get_dir(from, loc))
	if(!cover)
		return 1
	if (get_dist(P.starting, loc) <= 1) //Tables won't help you if people are THIS close
		return 1

	var/chance = 20
	if(ismob(P.original) && get_turf(P.original) == cover)
		var/mob/M = P.original
		if (M.lying)
			chance += 20				//Lying down lets you catch less bullets
	if(flipped)
		if(get_dir(loc, from) == dir)	//Flipped tables catch mroe bullets
			chance += 30
		else
			return 1					//But only from one side

	if(prob(chance))
		return 0 //blocked
	return 1

/obj/structure/table/bullet_act(obj/item/projectile/P)
	if(!(P.damage_type == BRUTE || P.damage_type == BURN))
		return 0

	if(take_damage(P.damage/2))
		//prevent tables with 1 health left from stopping bullets outright
		return PROJECTILE_CONTINUE //the projectile destroyed the table, so it gets to keep going

	visible_message("<span class='warning'>\The [P] hits [src]!</span>")
	return 0

/obj/structure/table/CheckExit(atom/movable/O as mob|obj, target as turf)
	if(istype(O) && O.checkpass(PASS_FLAG_TABLE))
		return 1
	if (flipped==1)
		if (get_dir(loc, target) == dir)
			return !density
		else
			return 1
	return 1


/obj/structure/table/MouseDrop_T(mob/target, mob/user)
	if (isrobot(user))
		return
	if (target.loc != loc)
		step(target, get_dir(target, loc))
	..()

/obj/structure/table/attackby(obj/item/W, mob/user, var/click_params)
	if (!W) return

	// Handle dismantling or placing things on the table from here on.
	if(isrobot(user))
		return

	if(W.loc != user) // This should stop mounted modules ending up outside the module.
		return

	if(istype(W, /obj/item/weapon/melee/energy/blade) || istype(W,/obj/item/psychic_power/psiblade/master/grand/paramount))
		var/datum/effect/effect/system/spark_spread/spark_system = new /datum/effect/effect/system/spark_spread()
		spark_system.set_up(5, 0, src.loc)
		spark_system.start()
		playsound(src.loc, 'sound/weapons/blade1.ogg', 50, 1)
		playsound(src.loc, "sparks", 50, 1)
		user.visible_message("<span class='danger'>\The [src] was sliced apart by [user]!</span>")
		break_to_parts()
		return

	if(can_plate && !material)
		to_chat(user, "<span class='warning'>There's nothing to put \the [W] on! Try adding plating to \the [src] first.</span>")
		return

	// Placing stuff on tables
	if(user.unEquip(W, src.loc))
		auto_align(W, click_params)
		return 1

/*
Automatic alignment of items to an invisible grid, defined by CELLS and CELLSIZE, defined in code/__defines/misc.dm.
Since the grid will be shifted to own a cell that is perfectly centered on the turf, we end up with two 'cell halves'
on edges of each row/column.
Each item defines a center_of_mass, which is the pixel of a sprite where its projected center of mass toward a turf
surface can be assumed. For a piece of paper, this will be in its center. For a bottle, it will be (near) the bottom
of the sprite.
auto_align() will then place the sprite so the defined center_of_mass is at the bottom left corner of the grid cell
closest to where the cursor has clicked on.
Note: This proc can be overwritten to allow for different types of auto-alignment.
*/
/obj/item/var/center_of_mass = "x=16;y=16" //can be null for no exact placement behaviour
/obj/structure/table/proc/auto_align(obj/item/W, click_params)
	if (!W.center_of_mass) // Clothing, material stacks, generally items with large sprites where exact placement would be unhandy.
		W.pixel_x = rand(-W.randpixel, W.randpixel)
		W.pixel_y = rand(-W.randpixel, W.randpixel)
		W.pixel_z = 0
		return

	if (!click_params)
		return

	var/list/click_data = params2list(click_params)
	if (!click_data["icon-x"] || !click_data["icon-y"])
		return

	// Calculation to apply new pixelshift.
	var/mouse_x = text2num(click_data["icon-x"])-1 // Ranging from 0 to 31
	var/mouse_y = text2num(click_data["icon-y"])-1

	var/cell_x = Clamp(round(mouse_x/CELLSIZE), 0, CELLS-1) // Ranging from 0 to CELLS-1
	var/cell_y = Clamp(round(mouse_y/CELLSIZE), 0, CELLS-1)

	var/list/center = cached_key_number_decode(W.center_of_mass)

	W.pixel_x = (CELLSIZE * (cell_x + 0.5)) - center["x"]
	W.pixel_y = (CELLSIZE * (cell_y + 0.5)) - center["y"]
	W.pixel_z = 0

/obj/structure/table/rack/auto_align(obj/item/W, click_params)
	if(W && !W.center_of_mass)
		..(W)

	var/i = -1
	for (var/obj/item/I in get_turf(src))
		if (I.anchored || !I.center_of_mass)
			continue
		i++
		I.pixel_x = 1  // There's a sprite layering bug for 0/0 pixelshift, so we avoid it.
		I.pixel_y = max(3-i*3, -3) + 1
		I.pixel_z = 0