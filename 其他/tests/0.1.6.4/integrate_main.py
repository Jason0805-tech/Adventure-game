from pathlib import Path
root=Path(__file__).resolve().parent/'candidate'
p=root/'main.gd';s=p.read_text()
def rep(old,new):
 global s
 assert old in s,old[:100];s=s.replace(old,new)
rep('0.1.6.3','v0.1.6-alpha.4')
rep('var health := 100.0','var health := 100.0\nvar sanity := 100.0\nvar survival = preload("res://sanity_system.gd").new()\nconst Balance = preload("res://survival_balance.gd")\nvar scout_rewarded := false')
rep('var power := 0\n','')
rep('wildlife.setup(self, resource_seed)','wildlife.setup(self, resource_seed)\n\tsurvival.setup(resource_seed)') if 'wildlife.setup(self, resource_seed)' in s else None
# actual _ready setup style handled below if needed
rep('direction.limit_length() * SPEED * delta','direction.limit_length() * SPEED * Balance.movement_scale(fullness) * delta')
rep('\t\t\tupdate_wildlife(dt)','\t\t\tupdate_wildlife(dt)\n\t\t\tsurvival.update(self,dt)')
rep('Camp has a lantern and keeps predators away.','Camp light slows predators; it is not an invincible refuge.\\nStand still in lit camp away from threats to restore sanity.')
rep('Wolves are quick. Bears are slower but stronger.','Wolves tire after pursuit. Use light or break their sight.\\nBears warn before charging: step sideways.')
rep('Fish restores fullness. H uses medicine to restore health.','Fish restores fullness and sanity. H uses medicine to heal.\\nI left supplies for your first visit: fish, medicine and a ward.')
rep('\t\t"scout":\n\t\t\tdialog=', '\t\t"scout":\n\t\t\tif not scout_rewarded:\n\t\t\t\tscout_rewarded=true\n\t\t\t\tgive_item("fish",2,npc_position+Vector2(24,22))\n\t\t\t\tgive_item("medicine",1,npc_position+Vector2(-24,22))\n\t\t\t\tgive_item("crystal",1,npc_position+Vector2(0,30))\n\t\t\tdialog=')
rep('item.taken=true;fullness=mini(100,fullness+22);notify("Ate berries. Fullness +22.")','item.taken=true;fullness=mini(100,fullness+22);survival.eat(self,2.0);notify("Ate berries. Fullness +22, sanity +2.")')
a=s.index('func advance_vitals(');b=s.index('\nfunc use_medicine',a)
s=s[:a]+'''func simulation_running() -> bool:
\treturn active_exploration() and not paused and not inventory and not crafting and dialog.is_empty() and not browser_suspended and not (mobile.enabled and get_viewport_rect().size.x < get_viewport_rect().size.y)

func advance_vitals(dt: float) -> void:
\tif not simulation_running(): return
\tvar elapsed_time := maxf(0,dt)
\tvar until_starving := maxf(0,(fullness-hunger_elapsed)/Balance.HUNGER_PER_SECOND)
\thunger_elapsed += elapsed_time * Balance.HUNGER_PER_SECOND
\tvar hunger_cost := int(hunger_elapsed + 0.0000001)
\tif hunger_cost > 0:
\t\tfullness = maxi(0,fullness-hunger_cost)
\t\thunger_elapsed = maxf(0,hunger_elapsed-hunger_cost)
\tvar starving_time := maxf(0,elapsed_time-until_starving)
\tif starving_time > 0: take_damage(starving_time*Balance.STARVATION_DAMAGE)
''' +s[b:]
rep('\tlighting.draw(self)\n','\tlighting.draw(self)\n\tsurvival.draw(self,screen)\n')
rep('"v0.1.6-alpha.4  /  THREE NIGHTS",16','"v0.1.6-alpha.4  /  THREE NIGHTS",15')
# A third painted bar in the old unused lower HUD row; same panel and icon-free custom sanity mark.
rep('\tpainted_status(Vector2(354,43),"Fullness",float(fullness),1,Color("bc984e"))','\tpainted_status(Vector2(354,43),"Fullness",float(fullness),1,Color("bc984e"))\n\tpainted_status(Vector2(24,88),"Sanity  "+survival.level(sanity),sanity,-1,Color("827b9e"))\n\tlabel_at(Vector2(354,116),"Resting in camp" if survival.resting else ("Hungry: slower movement" if fullness<25 else "Light protects your sanity"),15,Color("657259"))')
rep('\tdraw_texture_rect(status_art[icon],Rect2(origin + Vector2(0,5),Vector2(29,29)),false)','\tif icon>=0:draw_texture_rect(status_art[icon],Rect2(origin + Vector2(0,5),Vector2(29,29)),false)\n\telse:draw_sanity_mark(origin+Vector2(14,20),12.0)')
rep('var hint:String="CAMP REFUGE - lantern light and safety"','var hint:String=("CAMP REST - sanity recovers" if survival.resting else "CAMP LIGHT - slows threats; stay alert")')
rep('"duration":2.0 if target.kind=="water" else 0.8','"duration":Balance.action_duration(str(item.id),str(target.kind),fullness)')
rep('\t\t\t\t\tpower += result.kills.size()\n\t\t\t\t\tnotify("Wildlife defeated. Experience +%d." % result.kills.size())','\t\t\t\t\tnotify("Threat defeated. Keep your equipment repaired.")')
rep('bag.remove_uid(int(item.uid));fullness=mini(100,fullness+25);sanitize_hotbar();notify("Ate fish. Fullness +25.");return','bag.remove_uid(int(item.uid));fullness=mini(100,fullness+25);survival.eat(self,4.0);sanitize_hotbar();notify("Ate fish. Fullness +25, sanity +4.");return')
rep('return power + bag.best_power()','return bag.best_power()')
rep('\tvar tint := Color.WHITE\n\ttint.a = float(animal.alpha)','\tvar tint := Color(0.27,0.19,0.40,0.88) if animal.get("shadow",false) else Color.WHITE\n\ttint.a *= float(animal.alpha)')
# Warnings must be visible even in darkness (eyes alone are not adequate charge telegraphs).
rep('if species in ["wolf", "bear"] and lighting.sample(self,animal.p)>0.28 and (animal.p.distance_to(player) < 185.0 or bool(animal.warning)):','if species in ["wolf", "bear"] and ((lighting.sample(self,animal.p)>0.28 and animal.p.distance_to(player)<185.0) or bool(animal.warning)):')
rep('if bool(animal.warning): label_at(top + Vector2(-4, -9), "!", 22, Color("f1c47d"))','if bool(animal.warning):\n\t\t\tlabel_at(top + Vector2(-4, -9), "!", 22, Color("f1c47d"))\n\t\t\tif animal.state=="charge_warn":label_at(top+Vector2(-32,-32),"CHARGE",13,Color("f1c47d"))')
s+='''
func draw_sanity_mark(center: Vector2, radius: float) -> void:
\tvar points := PackedVector2Array()
\tfor i in range(18):
\t\tvar angle: float = TAU*i/18.0
\t\tpoints.append(center+Vector2(cos(angle),sin(angle))*radius*(0.91+0.08*sin(i*2.3)))
\tdraw_polyline(points,Color("827b9e"),2.5,true)
\tdraw_arc(center+Vector2(2,-1),radius*0.45,0.3,4.7,12,Color("827b9e"),2.3,true)
'''
p.write_text(s)
p=root/'mobile_ui.gd';s=p.read_text().replace('0.1.6.3','v0.1.6-alpha.4')
s=s.replace('\tgame.draw_texture_rect(game.status_art[icon],Rect2(p+Vector2(0,3),Vector2(37,37)),false)','\tif icon>=0:game.draw_texture_rect(game.status_art[icon],Rect2(p+Vector2(0,3),Vector2(37,37)),false)\n\telse:game.draw_sanity_mark(p+Vector2(18,20),16.0)')
s=s.replace('"v0.1.6-alpha.4   ·   SURVIVE THREE NIGHTS",21','"v0.1.6-alpha.4  ·  THREE NIGHTS",20')
# Mobile minimum landscape world width is 1278. Four columns fit without covering controls.
s=s.replace('status(game,Vector2(425,24),"Health"','status(game,Vector2(370,24),"Health"').replace('status(game,Vector2(716,24),"Fullness"','status(game,Vector2(655,24),"Fullness"')
s=s.replace('\tvar timer:String=', '\tstatus(game,Vector2(940,24),"Sanity",game.sanity,-1,Color("827b9e"))\n\tvar timer:String=')
s=s.replace('Vector2(425,105)','Vector2(370,105)').replace('if screen.x>1250:', 'if screen.x>1550:')
s=s.replace('else:text(game,Vector2(32,107),timer,23,Color("875c31"))','else:text(game,Vector2(32,107),timer,23,Color("875c31"))\n\ttext(game,Vector2(940,105),"RESTING" if game.survival.resting else game.survival.level(game.sanity),22,Color("827b9e"))')
s=s.replace('"Health %d / 100   ·   Fullness %d / 100"%[game.health,game.fullness]','"Health %d   ·   Fullness %d   ·   Sanity %d"%[game.health,game.fullness,game.sanity]')
p.write_text(s)
p=root/'item_data.gd';s=p.read_text().replace('restore 25 fullness.','restore 25 fullness and 4 sanity.').replace('Stronger chopping tool: two tree damage per hit.','Fast chopping: 0.58 s swings, two tree damage per hit.').replace('Workbench upgrade of a large stone sword. Replaces the original blade.','Fast 0.60 s swings and 48 damage. Workbench upgrade replaces the original blade.')
s=s.replace('"bench":false}\n]', '"bench":false},\n {"id":"crystal","cost":{"ore":1,"rock":2,"rope":1},"bench":true}\n]')
p.write_text(s)
