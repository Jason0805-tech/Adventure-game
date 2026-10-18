from pathlib import Path
import shutil,tempfile,plistlib,subprocess,json,hashlib
root=Path(__file__).resolve().parents[2];p=root/'output/adventure game 0.1.5.2'
with tempfile.TemporaryDirectory(prefix='forest0152-') as tmp:
 stage=Path(tmp)/'Forest Wanderer.app';(stage/'Contents/MacOS').mkdir(parents=True)
 resources=stage/'Contents/Resources';resources.mkdir()
 exe=stage/'Contents/MacOS/ForestWanderer0152'
 shutil.copyfile('/Applications/Godot.app/Contents/MacOS/Godot',exe);exe.chmod(0o755)
 for name in ['project.godot','main.gd','main.tscn']:shutil.copyfile(p/name,resources/name)
 shutil.copytree(p/'assets',resources/'assets',ignore=shutil.ignore_patterns('*.import','*.uid','.DS_Store'))
 with (stage/'Contents/Info.plist').open('wb') as file:
  plistlib.dump({'CFBundleName':'Forest Wanderer 0.1.5.2','CFBundleDisplayName':'Forest Wanderer 0.1.5.2','CFBundleIdentifier':'local.forestwanderer.v0152','CFBundleExecutable':'ForestWanderer0152','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.5.2','CFBundleVersion':'0.1.5.2','NSHighResolutionCapable':True},file)
 subprocess.run(['xattr','-dr','com.apple.FinderInfo',str(stage)],check=False)
 subprocess.run(['codesign','--force','--deep','--sign','-',str(stage)],check=True)
 target=p/stage.name
 shutil.copytree(stage,target,dirs_exist_ok=True)
 for attr in ['com.apple.FinderInfo','com.apple.ResourceFork']:
  subprocess.run(['xattr','-dr',attr,str(target)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
 subprocess.run(['codesign','--verify','--deep',str(target)],check=True)
 manifest={}
 for source in [p/'project.godot',p/'main.gd',p/'main.tscn',*sorted((p/'assets').glob('*'))]:
  if not source.is_file() or source.suffix in ['.import','.uid']:continue
  relative=str(source.relative_to(p));digest=hashlib.sha256(source.read_bytes()).hexdigest()
  assert digest==hashlib.sha256((target/'Contents/Resources'/relative).read_bytes()).hexdigest(),relative
  manifest[relative]=digest
 (root/'tests/0.1.5.2/bundle-manifest.json').write_text(json.dumps(manifest,indent=2))
 print('BUNDLE_VERIFIED',target,'matching runtime files:',len(manifest))
