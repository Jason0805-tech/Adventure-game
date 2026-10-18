from pathlib import Path
import shutil,tempfile,plistlib,subprocess,json,hashlib
root=Path(__file__).resolve().parents[2]
p=root/'output/adventure game 0.1.5.4'
test=root/'tests/0.1.5.4'
with tempfile.TemporaryDirectory(prefix='forest0154-') as tmp:
 stage=Path(tmp)/'Forest Wanderer.app'
 mac=stage/'Contents/MacOS';mac.mkdir(parents=True)
 resources=stage/'Contents/Resources';resources.mkdir()
 engine=mac/'GodotRuntime'
 shutil.copyfile('/Applications/Godot.app/Contents/MacOS/Godot',engine);engine.chmod(0o755)
 launcher=mac/'ForestWanderer0154'
 subprocess.run(['/usr/bin/swiftc','-O','-module-cache-path','/tmp/forest0154-swift-cache',str(test/'launcher.swift'),'-o',str(launcher)],check=True)
 launcher.chmod(0o755)
 for name in ['project.godot','main.gd','main.tscn','ENGINE_LICENSES.txt']:
  shutil.copyfile(p/name,resources/name)
 shutil.copytree(p/'assets',resources/'assets',ignore=shutil.ignore_patterns('*.import','*.uid','.DS_Store'))
 with (stage/'Contents/Info.plist').open('wb') as file:
  plistlib.dump({'CFBundleName':'Forest Wanderer 0.1.5.4','CFBundleDisplayName':'Forest Wanderer 0.1.5.4','CFBundleIdentifier':'local.forestwanderer.v0154','CFBundleExecutable':'ForestWanderer0154','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.5.4','CFBundleVersion':'0.1.5.4','NSHighResolutionCapable':True},file)
 for attr in ['com.apple.FinderInfo','com.apple.ResourceFork']:
  subprocess.run(['xattr','-dr',attr,str(stage)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
 subprocess.run(['codesign','--force','--deep','--sign','-',str(stage)],check=True)
 target=p/stage.name
 shutil.copytree(stage,target,dirs_exist_ok=True)
 for attr in ['com.apple.FinderInfo','com.apple.ResourceFork']:
  subprocess.run(['xattr','-dr',attr,str(target)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
 subprocess.run(['codesign','--verify','--deep',str(target)],check=True)
 manifest={}
 for source in [p/'project.godot',p/'main.gd',p/'main.tscn',p/'ENGINE_LICENSES.txt',*sorted((p/'assets').glob('*'))]:
  if not source.is_file() or source.suffix in ['.import','.uid']:continue
  relative=str(source.relative_to(p));digest=hashlib.sha256(source.read_bytes()).hexdigest()
  assert digest==hashlib.sha256((target/'Contents/Resources'/relative).read_bytes()).hexdigest(),relative
  manifest[relative]=digest
 (test/'bundle-manifest.json').write_text(json.dumps(manifest,indent=2))
 print('BUNDLE_VERIFIED',target,'matching runtime files:',len(manifest),flush=True)
 # Verify the actual app launcher from outside the project, including path
 # pinning and engine startup, rather than assuming Finder's working directory.
 result=subprocess.run([str(target/'Contents/MacOS/ForestWanderer0154'),'--headless','--quit-after','6','--log-file',str(test/'app-startup-engine.log')],cwd='/tmp',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=35)
 (test/'app-startup.log').write_text(result.stdout)
 assert result.returncode==0 and 'GAME_READY 0.1.5.4' in result.stdout and 'SCRIPT ERROR' not in result.stdout,result.stdout
 subprocess.run(['codesign','--verify','--deep',str(target)],check=True)
 print('APP_LAUNCHER_HEADLESS_STARTUP_OK',flush=True)
