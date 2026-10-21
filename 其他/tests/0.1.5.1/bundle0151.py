from pathlib import Path
import shutil, tempfile, plistlib, subprocess
p=Path(__file__).resolve().parents[2] / 'output/adventure game 0.1.5.1'
stage=Path(tempfile.mkdtemp(prefix='forest0151-'))/'Forest Wanderer.app'
(stage/'Contents/MacOS').mkdir(parents=True)
r=stage/'Contents/Resources'; r.mkdir()
shutil.copyfile('/Applications/Godot.app/Contents/MacOS/Godot',stage/'Contents/MacOS/ForestWanderer')
(stage/'Contents/MacOS/ForestWanderer').chmod(0o755)
for name in ['project.godot','main.gd','main.tscn']:
 shutil.copyfile(p/name,r/name)
shutil.copytree(p/'assets',r/'assets',ignore=shutil.ignore_patterns('*.import'))
with (stage/'Contents/Info.plist').open('wb') as f:
 plistlib.dump({'CFBundleName':'Forest Wanderer','CFBundleDisplayName':'Forest Wanderer 0.1.5.1','CFBundleIdentifier':'local.forestwanderer.v0151','CFBundleExecutable':'ForestWanderer','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.5.1','CFBundleVersion':'0.1.5.1','NSHighResolutionCapable':True},f)
subprocess.run(['xattr','-dr','com.apple.FinderInfo',str(stage)],check=False)
subprocess.run(['codesign','--force','--deep','--sign','-',str(stage)],check=True)
shutil.copytree(stage,p/stage.name,dirs_exist_ok=True)
subprocess.run(['codesign','--force','--deep','--sign','-',str(p/stage.name)],check=True)
print(p/stage.name)
