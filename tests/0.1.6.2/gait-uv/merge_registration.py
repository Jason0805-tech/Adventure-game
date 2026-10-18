from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3]
TEST=ROOT/'tests/0.1.6.2/gait-uv'
p=ROOT/'output/adventure game 0.1.6.2/assets/animal_atlas.json';metadata=json.loads(p.read_text())
recommend=json.loads((TEST/'recommended-ground-registration.json').read_text())
aliases={'front_near':'front_right','front_far':'front_left','hind_near':'hind_right','hind_far':'hind_left'}
phases={'front_left':0,'front_right':.5,'hind_left':.75,'hind_right':.25}
for species in ['wolf','deer','bear','fox','rabbit']:
 source_path=TEST/('source-legs-'+species+'.json');source=json.loads(source_path.read_text());defs=source['species'][species]
 if species=='deer':
  for leg in defs['2']['legs']:
   leg['name']=aliases.get(leg['name'],leg['name']);leg['phase']=phases[leg['name']]
 for dk,definition in defs.items():
  recs=recommend.get(species,{}).get(dk,{})
  for leg in definition['legs']:
   rec=recs.get(leg['name'])
   if rec is None:
    old=next((k for k,v in aliases.items()if v==leg['name']),None)
    rec=recs.get(old,{})
   for key in ['reach','rest_shift']:
    if key in rec:leg[key]=rec[key]
 metadata['species'][species]['source_skin']=defs
 metadata['species'][species]['render_mode']='painted-native-skin-v2'
 source_path.write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n')
p.write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
print('NATIVE_SKIN_REGISTRATION_MERGED',sum(len(m['source_skin'])for m in metadata['species'].values()),'headings')
