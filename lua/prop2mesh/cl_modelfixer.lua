--[[

]]
local prop2mesh = prop2mesh
local string = string

local genericmodel, genericfolder, genericmodellist, genericfolderlist, blockedmodel
local specialmodel, specialfolder = {}, {}


--[[

]]
function prop2mesh.isBlockedModel(modelpath)
	return blockedmodel[modelpath]
end

function prop2mesh.loadModelFixer()
	if not genericmodel then
		genericmodel = {}
		for s in string.gmatch(genericmodellist, "[^\r\n]+") do
		    genericmodel[s] = true
		end
	end
	if not genericfolder then
		genericfolder = {}
		for s in string.gmatch(genericfolderlist, "[^\r\n]+") do
		    genericfolder[s] = true
		end
	end
	--print("Loading model fixers")
end

function prop2mesh.unloadModelFixer()
	if genericmodel then
		genericmodel = nil
	end
	if genericfolder then
		genericfolder = nil
	end
	--print("Unloading model fixers")
end

function prop2mesh.getModelFix(modelpath)
	if specialmodel[modelpath] or genericmodel[modelpath] then
		return specialmodel[modelpath] or genericmodel[modelpath]
	end
	local trunc = string.GetPathFromFilename(modelpath)
	return specialfolder[trunc] or genericfolder[trunc]
end


--[[
	BADDIES
]]
blockedmodel = {
	["models/lubprops/seat/raceseat2.mdl"] = true,
	["models/lubprops/seat/raceseat.mdl"] = true,
}


--[[
	SPECIAL FOLDERS
]]
specialfolder["models/sprops/trans/wheel_b/"] = function(partnum, numparts, rotated, normal)
	if partnum == 1 then return rotated else return normal end
end

specialfolder["models/sprops/trans/wheel_d/"] = function(partnum, numparts, rotated, normal)
	if partnum == 1 or partnum == 2 then return rotated else return normal end
end


--[[
	SPECIAL MODELS
]]
local fix = function(partnum, numparts, rotated, normal)
	if partnum == 1 then return rotated else return normal end
end
specialmodel["models/sprops/trans/miscwheels/thin_moto15.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/thin_moto20.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/thin_moto25.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/thin_moto30.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/thick_moto15.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/thick_moto20.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/thick_moto25.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/thick_moto30.mdl"] = fix

local fix = function(partnum, numparts, rotated, normal)
	if partnum == 1 or partnum == 2 then return rotated else return normal end
end
specialmodel["models/sprops/trans/miscwheels/tank15.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/tank20.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/tank25.mdl"] = fix
specialmodel["models/sprops/trans/miscwheels/tank30.mdl"] = fix

local fix = function(partnum, numparts, rotated, normal)
	local angle = Angle(rotated)
	angle:RotateAroundAxis(angle:Forward(), 90)
	return angle
end
specialmodel["models/props_mining/diesel_generator_crank.mdl"] = fix
specialmodel["models/props/de_nuke/hr_nuke/nuke_vent_bombsite/nuke_vent_bombsite_breakable_a.mdl"] = fix
specialmodel["models/props/de_nuke/hr_nuke/nuke_vent_bombsite/nuke_vent_bombsite_breakable_b.mdl"] = fix
specialmodel["models/props/de_nuke/hr_nuke/nuke_vent_bombsite/nuke_vent_bombsite_breakable_c.mdl"] = fix


--[[
	GENERIC MODELS
]]
genericmodellist =
[[models/autocannon/semiautocannon_25mm.mdl
models/autocannon/semiautocannon_37mm.mdl
models/autocannon/semiautocannon_45mm.mdl
models/autocannon/semiautocannon_57mm.mdl
models/autocannon/semiautocannon_76mm.mdl
models/balloons/balloon_classicheart.mdl
models/balloons/balloon_dog.mdl
models/balloons/balloon_star.mdl
models/balloons/hot_airballoon.mdl
models/balloons/hot_airballoon_basket.mdl
models/blacknecro/ledboard60.mdl
models/blacknecro/tv_plasma_4_3.mdl
models/chairs/armchair.mdl
models/cheeze/wires/gyroscope.mdl
models/cheeze/wires/ram.mdl
models/cheeze/wires/router.mdl
models/cheeze/wires/wireless_card.mdl
models/combinecannon/cironwall.mdl
models/combinecannon/remnants.mdl
models/dynamite/dynamite.mdl
models/engines/emotorlarge.mdl
models/engines/emotormed.mdl
models/engines/emotorsmall.mdl
models/engines/gasturbine_l.mdl
models/engines/gasturbine_m.mdl
models/engines/gasturbine_s.mdl
models/engines/linear_l.mdl
models/engines/linear_m.mdl
models/engines/linear_s.mdl
models/engines/radial7l.mdl
models/engines/radial7m.mdl
models/engines/radial7s.mdl
models/engines/transaxial_l.mdl
models/engines/transaxial_m.mdl
models/engines/transaxial_s.mdl
models/engines/turbine_l.mdl
models/engines/turbine_m.mdl
models/engines/turbine_s.mdl
models/engines/wankel_2_med.mdl
models/engines/wankel_2_small.mdl
models/engines/wankel_3_med.mdl
models/engines/wankel_4_med.mdl
models/extras/info_speech.mdl
models/food/burger.mdl
models/food/hotdog.mdl
models/gears/planet_16.mdl
models/gears/planet_mount.mdl
models/gibs/helicopter_brokenpiece_01.mdl
models/gibs/helicopter_brokenpiece_02.mdl
models/gibs/helicopter_brokenpiece_03.mdl
models/gibs/helicopter_brokenpiece_04_cockpit.mdl
models/gibs/helicopter_brokenpiece_05_tailfan.mdl
models/gibs/helicopter_brokenpiece_06_body.mdl
models/gibs/shield_scanner_gib1.mdl
models/gibs/shield_scanner_gib2.mdl
models/gibs/shield_scanner_gib3.mdl
models/gibs/shield_scanner_gib4.mdl
models/gibs/shield_scanner_gib5.mdl
models/gibs/shield_scanner_gib6.mdl
models/gibs/strider_gib1.mdl
models/gibs/strider_gib2.mdl
models/gibs/strider_gib3.mdl
models/gibs/strider_gib4.mdl
models/gibs/strider_gib5.mdl
models/gibs/strider_gib6.mdl
models/gibs/strider_gib7.mdl
models/holograms/hexagon.mdl
models/holograms/icosphere.mdl
models/holograms/icosphere2.mdl
models/holograms/icosphere3.mdl
models/holograms/prism.mdl
models/holograms/sphere.mdl
models/holograms/tetra.mdl
models/howitzer/howitzer_75mm.mdl
models/howitzer/howitzer_105mm.mdl
models/howitzer/howitzer_122mm.mdl
models/howitzer/howitzer_155mm.mdl
models/howitzer/howitzer_203mm.mdl
models/howitzer/howitzer_240mm.mdl
models/howitzer/howitzer_290mm.mdl
models/hunter/plates/plate05x05_rounded.mdl
models/hunter/plates/plate1x3x1trap.mdl
models/hunter/plates/plate1x4x2trap.mdl
models/hunter/plates/plate1x4x2trap1.mdl
models/items/357ammo.mdl
models/items/357ammobox.mdl
models/items/ammocrate_ar2.mdl
models/items/ammocrate_grenade.mdl
models/items/ammocrate_rockets.mdl
models/items/ammocrate_smg1.mdl
models/items/ammopack_medium.mdl
models/items/ammopack_small.mdl
models/items/crossbowrounds.mdl
models/items/cs_gift.mdl
models/lamps/torch.mdl
models/machinegun/machinegun_20mm_compact.mdl
models/machinegun/machinegun_30mm_compact.mdl
models/machinegun/machinegun_40mm_compact.mdl
models/maxofs2d/button_01.mdl
models/maxofs2d/button_03.mdl
models/maxofs2d/button_04.mdl
models/maxofs2d/button_06.mdl
models/maxofs2d/button_slider.mdl
models/maxofs2d/camera.mdl
models/maxofs2d/logo_gmod_b.mdl
models/mechanics/articulating/arm_base_b.mdl
models/nova/airboat_seat.mdl
models/nova/chair_office01.mdl
models/nova/chair_office02.mdl
models/nova/chair_plastic01.mdl
models/nova/chair_wood01.mdl
models/nova/jalopy_seat.mdl
models/nova/jeep_seat.mdl
models/props/coop_kashbah/coop_stealth_boat/coop_stealth_boat_animated.mdl
models/props/de_inferno/hr_i/inferno_vintage_radio/inferno_vintage_radio.mdl
models/props_c17/doll01.mdl
models/props_c17/door01_left.mdl
models/props_c17/door02_double.mdl
models/props_c17/suitcase_passenger_physics.mdl
models/props_c17/trappropeller_blade.mdl
models/props_c17/tv_monitor01.mdl
models/props_canal/mattpipe.mdl
models/props_canal/winch01b.mdl
models/props_canal/winch02b.mdl
models/props_canal/winch02c.mdl
models/props_canal/winch02d.mdl
models/props_combine/breenbust.mdl
models/props_combine/breenbust_chunk01.mdl
models/props_combine/breenbust_chunk02.mdl
models/props_combine/breenbust_chunk04.mdl
models/props_combine/breenbust_chunk05.mdl
models/props_combine/breenbust_chunk06.mdl
models/props_combine/breenbust_chunk07.mdl
models/props_combine/breenchair.mdl
models/props_combine/breenclock.mdl
models/props_combine/breenpod.mdl
models/props_combine/breenpod_inner.mdl
models/props_combine/breen_tube.mdl
models/props_combine/bunker_gun01.mdl
models/props_combine/bustedarm.mdl
models/props_combine/cell_01_pod_cheap.mdl
models/props_combine/combinebutton.mdl
models/props_combine/combinethumper001a.mdl
models/props_combine/combinethumper002.mdl
models/props_combine/combine_ballsocket.mdl
models/props_combine/combine_mine01.mdl
models/props_combine/combine_tptimer.mdl
models/props_combine/eli_pod_inner.mdl
models/props_combine/health_charger001.mdl
models/props_combine/introomarea.mdl
models/props_combine/soldier_bed.mdl
models/props_combine/stalkerpod_physanim.mdl
models/props_doors/door01_dynamic.mdl
models/props_doors/door03_slotted_left.mdl
models/props_doors/doorklab01.mdl
models/props_junk/ravenholmsign.mdl
models/props_lab/blastdoor001a.mdl
models/props_lab/blastdoor001b.mdl
models/props_lab/blastdoor001c.mdl
models/props_lab/blastwindow.mdl
models/props_lab/citizenradio.mdl
models/props_lab/clipboard.mdl
models/props_lab/crematorcase.mdl
models/props_lab/hevplate.mdl
models/props_lab/huladoll.mdl
models/props_lab/kennel_physics.mdl
models/props_lab/keypad.mdl
models/props_lab/ravendoor.mdl
models/props_lab/tpplug.mdl
models/props_lab/tpswitch.mdl
models/props_mining/ceiling_winch01.mdl
models/props_mining/control_lever01.mdl
models/props_mining/diesel_generator.mdl
models/props_mining/elevator_winch_cog.mdl
models/props_mining/switch01.mdl
models/props_mining/switch_updown01.mdl
models/props_phx/amraam.mdl
models/props_phx/box_amraam.mdl
models/props_phx/box_torpedo.mdl
models/props_phx/cannon.mdl
models/props_phx/carseat2.mdl
models/props_phx/carseat3.mdl
models/props_phx/construct/metal_angle90.mdl
models/props_phx/construct/metal_angle180.mdl
models/props_phx/construct/metal_dome90.mdl
models/props_phx/construct/metal_dome180.mdl
models/props_phx/construct/metal_plate1.mdl
models/props_phx/construct/metal_plate1x2.mdl
models/props_phx/construct/metal_plate2x2.mdl
models/props_phx/construct/metal_plate2x4.mdl
models/props_phx/construct/metal_plate4x4.mdl
models/props_phx/construct/metal_plate_curve.mdl
models/props_phx/construct/metal_plate_curve2.mdl
models/props_phx/construct/metal_plate_curve2x2.mdl
models/props_phx/construct/metal_plate_curve180.mdl
models/props_phx/construct/metal_wire1x1x1.mdl
models/props_phx/construct/metal_wire1x1x2.mdl
models/props_phx/construct/metal_wire1x1x2b.mdl
models/props_phx/construct/metal_wire1x2.mdl
models/props_phx/construct/metal_wire1x2b.mdl
models/props_phx/construct/metal_wire_angle90x1.mdl
models/props_phx/construct/metal_wire_angle90x2.mdl
models/props_phx/construct/metal_wire_angle180x1.mdl
models/props_phx/construct/metal_wire_angle180x2.mdl
models/props_phx/facepunch_logo.mdl
models/props_phx/games/chess/black_king.mdl
models/props_phx/games/chess/black_knight.mdl
models/props_phx/games/chess/board.mdl
models/props_phx/games/chess/white_king.mdl
models/props_phx/games/chess/white_knight.mdl
models/props_phx/gears/bevel9.mdl
models/props_phx/gears/rack9.mdl
models/props_phx/gears/rack18.mdl
models/props_phx/gears/rack36.mdl
models/props_phx/gears/rack70.mdl
models/props_phx/gears/spur9.mdl
models/props_phx/huge/road_curve.mdl
models/props_phx/huge/road_long.mdl
models/props_phx/huge/road_medium.mdl
models/props_phx/huge/road_short.mdl
models/props_phx/mechanics/slider1.mdl
models/props_phx/mechanics/slider2.mdl
models/props_phx/mk-82.mdl
models/props_phx/playfield.mdl
models/props_phx/torpedo.mdl
models/props_phx/trains/double_wheels_base.mdl
models/props_phx/trains/fsd-overrun.mdl
models/props_phx/trains/fsd-overrun2.mdl
models/props_phx/trains/monorail1.mdl
models/props_phx/trains/monorail_curve.mdl
models/props_phx/trains/trackslides_both.mdl
models/props_phx/trains/trackslides_inner.mdl
models/props_phx/trains/trackslides_outer.mdl
models/props_phx/trains/wheel_base.mdl
models/props_phx/wheels/breakable_tire.mdl
models/props_phx/wheels/magnetic_large_base.mdl
models/props_phx/wheels/magnetic_med_base.mdl
models/props_phx/wheels/magnetic_small_base.mdl
models/props_phx/ww2bomb.mdl
models/props_placeable/witch_hatch_lid.mdl
models/props_survival/repulsor/repulsor.mdl
models/props_trainstation/passengercar001.mdl
models/props_trainstation/passengercar001_dam01a.mdl
models/props_trainstation/passengercar001_dam01c.mdl
models/props_trainstation/train_outro_car01.mdl
models/props_trainstation/train_outro_porch01.mdl
models/props_trainstation/train_outro_porch02.mdl
models/props_trainstation/train_outro_porch03.mdl
models/props_trainstation/wrecked_train.mdl
models/props_trainstation/wrecked_train_02.mdl
models/props_trainstation/wrecked_train_divider_01.mdl
models/props_trainstation/wrecked_train_door.mdl
models/props_trainstation/wrecked_train_panel_01.mdl
models/props_trainstation/wrecked_train_panel_02.mdl
models/props_trainstation/wrecked_train_panel_03.mdl
models/props_trainstation/wrecked_train_rack_01.mdl
models/props_trainstation/wrecked_train_rack_02.mdl
models/props_trainstation/wrecked_train_seat.mdl
models/props_vehicles/mining_car.mdl
models/props_vehicles/van001a_nodoor_physics.mdl
models/props_wasteland/cranemagnet01a.mdl
models/props_wasteland/wood_fence01a.mdl
models/props_wasteland/wood_fence01b.mdl
models/props_wasteland/wood_fence01c.mdl
models/quarterlife/fsd-overrun-toy.mdl
models/radar/radar_sp_big.mdl
models/radar/radar_sp_mid.mdl
models/radar/radar_sp_sml.mdl
models/rotarycannon/kw/14_5mmrac.mdl
models/rotarycannon/kw/20mmrac.mdl
models/rotarycannon/kw/30mmrac.mdl
models/segment.mdl
models/segment2.mdl
models/segment3.mdl
models/shells/shell_9mm.mdl
models/shells/shell_12gauge.mdl
models/shells/shell_57.mdl
models/shells/shell_338mag.mdl
models/shells/shell_556.mdl
models/shells/shell_762nato.mdl
models/sprops/trans/fender_a/a_fender30.mdl
models/sprops/trans/fender_a/a_fender35.mdl
models/sprops/trans/fender_a/a_fender40.mdl
models/sprops/trans/fender_a/a_fender45.mdl
models/sprops/trans/train/double_24.mdl
models/sprops/trans/train/double_36.mdl
models/sprops/trans/train/double_48.mdl
models/sprops/trans/train/double_72.mdl
models/sprops/trans/train/single_24.mdl
models/sprops/trans/train/single_36.mdl
models/sprops/trans/train/single_48.mdl
models/sprops/trans/train/single_72.mdl
models/thrusters/jetpack.mdl
models/vehicles/pilot_seat.mdl
models/vehicles/prisoner_pod.mdl
models/vehicles/prisoner_pod_inner.mdl
models/vehicles/vehicle_van.mdl
models/vehicles/vehicle_vandoor.mdl
models/wingf0x/altisasocket.mdl
models/wingf0x/ethernetplug.mdl
models/wingf0x/ethernetsocket.mdl
models/wingf0x/hdmiplug.mdl
models/wingf0x/hdmisocket.mdl
models/wingf0x/isaplug.mdl
models/wingf0x/isasocket.mdl
models/props_mvm/hologram_projector_closed.mdl
models/daktanks/shortcannon100mm2.mdl
models/daktanks/longcannon100mm2.mdl
models/daktanks/howitzer100mm2.mdl
models/daktanks/hmg100mm2.mdl
models/daktanks/cannon100mm2.mdl]]


--[[
	GENERIC FOLDERS
]]
genericfolderlist =
[[models/bull/gates/
models/bull/various/
models/cheeze/pcb/
models/combine_turrets/
models/engine/
models/fueltank/
models/jaanus/wiretool/
models/kobilica/
models/misc/
models/phxtended/
models/props_phx/construct/glass/
models/props_phx/construct/plastic/
models/props_phx/construct/windows/
models/props_phx/construct/wood/
models/props_phx/misc/
models/props_phx/trains/tracks/
models/sprops/trans/wheels_g/
models/sprops/trans/wheel_big_g/
models/sprops/trans/wheel_f/
models/squad/sf_bars/
models/squad/sf_plates/
models/squad/sf_tris/
models/squad/sf_tubes/
models/weapons/
models/wings/]]
