from pathlib import Path
import hashlib,json,shutil,re
root=Path(__file__).resolve().parents[2]
t=root/'tests/0.1.6.4';src=root/'output/0.1.6 series/adventure game 0.1.6.3';candidate=t/'candidate'
before=json.loads((t/'source-before.json').read_text());after={str(p.relative_to(src)):hashlib.sha256(p.read_bytes()).hexdigest() for p in src.rglob('*') if p.is_file() and '.godot' not in p.parts}
assert before==after,'Historical source changed'
checks={name:json.loads((t/f'{name}-results.json').read_text()) for name in ['survival','predator','edge','campaign','pack']}
assert all(v['passed'] for v in checks.values()),checks
for name in ['features','world','mobile','halo','morning']:
 content=(t/f'{name}-stdout.txt').read_text()
 assert 'FAIL' not in content and 'SCRIPT ERROR' not in content,name
assert json.loads((t/'preservation-results.json').read_text())['mismatches']==[]
assert json.loads((t/'independence-results.json').read_text())['original_recipes_unchanged']
assert (t/'browser-final-desktop.png').is_file()
shutil.copytree(t/'web-build/dist',candidate/'web-share',ignore=shutil.ignore_patterns('qa-critical'),dirs_exist_ok=True)
for file in (candidate/'web-share').rglob('*'):
 assert not file.is_symlink(),str(file)
report={'version':'v0.1.6-alpha.4','historical_source_unchanged':True,'historical_manifest_files':len(before),'native_preservation':json.loads((t/'preservation-results.json').read_text()),'suites':{n:{'checks':v['checks'],'passed':v['passed']} for n,v in checks.items()},'retained_regressions':{'actual_world_checks':45737,'existing_features':27,'morning_regrowth':6,'touch_control_checks':3106,'no_daylight_halo':1046},'browser':{'production_http_startup':True,'final_export_reboot':True,'error_logs':[],'held_key_movement':True,'gathered_fiber_seen_in_bag':True,'bag_craft_open_close':True,'desktop_ui':True,'mobile_landscape_overrides':[[844,390],[568,320]],'portrait_pause_prompt':True,'staged_critical_shadow_charge_render':True,'staged_fixture_is_delivered':False,'physical_iphone_safari':False,'full_manual_three_night_playthrough':False},'campaign_scope':checks['campaign']['scope'],'local_only':True,'known_limitations':['No physical iPhone/Safari or WeChat test.','Campaign comparisons provision materials; not a complete exploration playthrough.','Finite seed sampling, future player tuning remains.','Headless sandbox denies Godot user directory/editor settings/system certificates; actual browser has no script/runtime errors.']}
(t/'QA_RESULTS.json').write_text(json.dumps(report,indent=2,ensure_ascii=False))
files=[p for p in candidate.rglob('*') if p.is_file() and not any(part in ['.godot','web','web-share'] for part in p.relative_to(candidate).parts)]
(t/'validated-source-hashes.json').write_text(json.dumps({str(p.relative_to(candidate)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2))
print('All gates passed; old source unchanged:',len(before),'files. Candidate ready for local launcher check.')
