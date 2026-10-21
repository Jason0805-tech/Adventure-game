from pathlib import Path
import shutil, tempfile, plistlib, subprocess
root=Path(__file__).resolve().parents[2]
project=root/'output/adventure game 0.1.5.6'
test=root/'tests/0.1.5.6'
with tempfile.TemporaryDirectory(prefix='forest0156-') as tmp:
    stage=Path(tmp)/'Forest Wanderer.app'
    mac=stage/'Contents/MacOS';mac.mkdir(parents=True)
    resources=stage/'Contents/Resources';resources.mkdir()
    engine=mac/'GodotRuntime'
    shutil.copyfile('/Applications/Godot.app/Contents/MacOS/Godot',engine)
    engine.chmod(0o755)
    launcher=mac/'ForestWanderer0156'
    subprocess.run(['/usr/bin/swiftc','-O','-module-cache-path','/tmp/forest0156-swift-cache',str(test/'launcher.swift'),'-o',str(launcher)],check=True)
    launcher.chmod(0o755)
    for name in ['project.godot','main.gd','main.tscn','item_data.gd','inventory.gd','ENGINE_LICENSES.txt']:
        shutil.copyfile(project/name,resources/name)
    shutil.copytree(project/'assets',resources/'assets',ignore=shutil.ignore_patterns('*.import','*.uid','.DS_Store'))
    with (stage/'Contents/Info.plist').open('wb') as file:
        plistlib.dump({'CFBundleName':'Forest Wanderer 0.1.5.6','CFBundleDisplayName':'Forest Wanderer 0.1.5.6','CFBundleIdentifier':'local.forestwanderer.v0156','CFBundleExecutable':'ForestWanderer0156','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.5.6','CFBundleVersion':'0.1.5.6','NSHighResolutionCapable':True},file)
    for attr in ['com.apple.FinderInfo','com.apple.ResourceFork']:
        subprocess.run(['xattr','-dr',attr,str(stage)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
    subprocess.run(['codesign','--force','--deep','--sign','-',str(stage)],check=True)
    target=project/stage.name
    shutil.copytree(stage,target,dirs_exist_ok=True)
    for attr in ['com.apple.FinderInfo','com.apple.ResourceFork']:
        subprocess.run(['xattr','-dr',attr,str(target)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
    subprocess.run(['codesign','--verify','--deep',str(target)],check=True)
    print('PACKAGED',target)
