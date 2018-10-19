/proc/get_station_areas(var/list/area/excluded_areas)
	var/list/area/grand_list_of_areas = list()
	// Assemble areas that all exists (See DM reference if you are confused about loop labels)
	looping_station_areas:
		for(var/parentpath in global.the_station_areas)
			// Check its not excluded
			for(var/excluded_path in excluded_areas)
				if(ispath(parentpath, excluded_path))
					continue looping_station_areas
			// Otherwise add it and all subtypes that exist on the map to our grand list
			for(var/areapath in typesof(parentpath))
				var/area/A = locate(areapath) // Check if it actually exists
				if(istype(A) && A.z in using_map.player_levels)
					grand_list_of_areas += A
	return grand_list_of_areas