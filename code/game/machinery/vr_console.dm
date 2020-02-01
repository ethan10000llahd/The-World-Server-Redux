/obj/machinery/vr_sleeper
	name = "virtual reality sleeper"
	desc = "A fancy bed with built-in sensory I/O ports and connectors to interface users' minds with their bodies in virtual reality."
	icon = 'icons/obj/Cryogenic2.dmi'
	icon_state = "syndipod_0"
	density = 1
	anchored = 1
	circuit = /obj/item/weapon/circuitboard/vr_sleeper
	var/mob/living/carbon/human/occupant = null
	var/mob/living/carbon/human/avatar = null
	var/datum/mind/vr_mind = null

	var/force_removal = FALSE	// allow force removal (important for prison VR sets)

	use_power = 1
	idle_power_usage = 15
	active_power_usage = 200
	light_color = "#FF0000"

/obj/machinery/vr_sleeper/examine(mob/user)
	..()
	if(occupant)
		to_chat(user, "You see <b>[occupant]</b> inside. The game title above them says <b>[get_area(occupant)]</b>.")

/obj/machinery/vr_sleeper/prison_vr
	name = "prison virtual reality sleeper"
	desc = "An inmate has to pass the time somehow. This is how."
	force_removal = TRUE

/obj/machinery/vr_sleeper/New()
	..()
	component_parts = list()
	component_parts += new /obj/item/weapon/stock_parts/scanning_module(src)
	component_parts += new /obj/item/stack/material/glass/reinforced(src, 2)

	RefreshParts()

/obj/machinery/vr_sleeper/initialize()
	. = ..()
	update_icon()

/obj/machinery/vr_sleeper/process()
	if(stat & (NOPOWER|BROKEN))
		return

/obj/machinery/vr_sleeper/update_icon()
	icon_state = "syndipod_[occupant ? "1" : "0"]"

/obj/machinery/vr_sleeper/Topic(href, href_list)
	if(..())
		return 1

	if(usr == occupant)
		to_chat(usr, "<span class='warning'>You can't reach the controls from the inside.</span>")
		return

	add_fingerprint(usr)

	if(href_list["eject"])
		go_out()

	return 1

/obj/machinery/vr_sleeper/attackby(var/obj/item/I, var/mob/user)
	add_fingerprint(user)
	if(default_deconstruction_screwdriver(user, I))
		return
	else if(default_deconstruction_crowbar(user, I))
		if(occupant && avatar)
			avatar.exit_vr()
			avatar = null
			go_out()
		return


/obj/machinery/vr_sleeper/MouseDrop_T(var/mob/living/carbon/human/target, var/mob/living/carbon/human/user)
	if(user.stat || user.lying || !Adjacent(user) || !target.Adjacent(user)|| !isliving(target))
		return
	go_in(target, user)



/obj/machinery/sleeper/relaymove(var/mob/user)
	..()
	if(usr.incapacitated())
		return
	go_out()



/obj/machinery/vr_sleeper/emp_act(var/severity)
	if(stat & (BROKEN|NOPOWER))
		..(severity)
		return

	if(occupant)
		// This will eject the user from VR
		// ### Fry the brain?
		go_out()

	..(severity)

/obj/machinery/vr_sleeper/verb/eject()
	set src in oview(1)
	set category = "Object"
	set name = "Eject VR Capsule"

	if(usr.incapacitated())
		return

	if(!occupant)
		return

	if(avatar && !force_removal)
		if(alert(avatar, "Someone wants to remove you from virtual reality. Do you want to leave?", "Leave VR?", "Yes", "No") == "No")
			return

	// The player in VR is fine with leaving, kick them out and reset avatar
	if(avatar)
		avatar.exit_vr()
		avatar = null

	go_out()
	add_fingerprint(usr)

/obj/machinery/vr_sleeper/verb/climb_in()
	set src in oview(1)
	set category = "Object"
	set name = "Enter VR Capsule"

	if(usr.incapacitated())
		return
	go_in(usr, usr)
	add_fingerprint(usr)

/obj/machinery/vr_sleeper/relaymove(mob/user as mob)
	if(user.incapacitated())
		return 0 //maybe they should be able to get out with cuffs, but whatever
	go_out()

/obj/machinery/vr_sleeper/proc/go_in(var/mob/M, var/mob/user)
	if(!M)
		return
	if(stat & (BROKEN|NOPOWER))
		return
	if(!ishuman(M))
		user << "<span class='warning'>\The [src] rejects [M] with a sharp beep.</span>"
	if(occupant)
		user << "<span class='warning'>\The [src] is already occupied.</span>"
		return

	if(M == user)
		visible_message("\The [user] starts climbing into \the [src].")
	else
		visible_message("\The [user] starts putting [M] into \the [src].")

	if(do_after(user, 20))
		if(occupant)
			to_chat(user, "<span class='warning'>\The [src] is already occupied.</span>")
			return
		M.stop_pulling()
		if(M.client)
			M.client.perspective = EYE_PERSPECTIVE
			M.client.eye = src
		M.loc = src
		update_use_power(2)
		occupant = M

		update_icon()

		enter_vr()
	return

/obj/machinery/vr_sleeper/proc/go_out()
	if(!occupant)
		return

	if(occupant.client)
		occupant.client.eye = occupant.client.mob
		occupant.client.perspective = MOB_PERSPECTIVE
	occupant.loc = src.loc
	occupant = null
	for(var/atom/movable/A in src) // In case an object was dropped inside or something
		if(A == circuit)
			continue
		if(A in component_parts)
			continue
		A.loc = src.loc
	update_use_power(1)
	update_icon()

/obj/machinery/vr_sleeper/proc/enter_vr()

	// No mob to transfer a mind from
	if(!occupant)
		return

	// No mind to transfer
	if(!occupant.mind)
		return

	// Mob doesn't have an active consciousness to send/receive from
	if(occupant.stat != CONSCIOUS)
		return

	avatar = occupant.vr_link
	// If they've already enterred VR, and are reconnecting, prompt if they want a new body
	if(avatar && alert(occupant, "You already have a Virtual Reality avatar. Would you like to use it?", "New avatar", "Yes", "No") == "No")
		// Delink the mob
		occupant.vr_link = null
		avatar = null

	if(!avatar)
		// Get the desired spawn location to put the body
		var/S = null
		var/list/vr_landmarks = list()
		for(var/obj/effect/landmark/virtual_reality/sloc in landmarks_list)
			vr_landmarks += sloc.name

		S = input(occupant, "Please select a location to spawn your avatar at:", "Spawn location") as null|anything in vr_landmarks
		if(!S)
			return 0

		for(var/obj/effect/landmark/virtual_reality/i in landmarks_list)
			if(i.name == S)
				S = i
				break

		avatar = new(S, "Virtual Reality Avatar")
		// If the user has a non-default (Human) bodyshape, make it match theirs.
		if(occupant.species.name != "Promethean" && occupant.species.name != "Human")
			avatar.shapeshifter_change_shape(occupant.species.name)
		avatar.forceMove(get_turf(S))			// Put the mob on the landmark, instead of inside it
		avatar.Sleeping(1)

		occupant.enter_vr(avatar)

		// Prompt for username after they've enterred the body.
		var/newname = sanitize(input(avatar, "You are entering virtual reality. Your username is currently [src.name]. Would you like to change it to something else?", "Name change") as null|text, MAX_NAME_LEN)
		if (newname)
			avatar.real_name = newname

	else
		occupant.enter_vr(avatar)

