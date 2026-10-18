from pathlib import Path
import shutil, tempfile, plistlib, subprocess
root=Path(__file__).resolve().parents[2]
project=root/'output/adventure game 0.1.5.11'
test=root/'tests/0.1.5.11'
with tempfile.TemporaryDirectory(prefix='forest01511-') as tmp:
    stage=Path(tmp)/'Forest Wanderer.app'
    mac=stage/'Contents/MacOS';mac.mkdir(parents=True)
    resources=stage/'Contents/Resources';resources.mkdir()
    engine=mac/'GodotRuntime'
    shutil.copyfile('/Applications/Godot.app/Contents/MacOS/Godot',engine)
    engine.chmod(0o755)
    launcher=mac/'ForestWanderer01511'
    subprocess.run(['/usr/bin/swiftc','-O','-module-cache-path','/tmp/forest01511-swift-cache',str(test/'launcher.swift'),'-o',str(launcher)],check=True)
    launcher.chmod(0o755)
    for name in ['project.godot','main.gd','main.tscn','item_data.gd','inventory.gd','world_geometry.gd','ground_painter.gd','paint_density.gd','depth_layers.gd','collision_profiles.json','ENGINE_LICENSES.txt']:
        shutil.copyfile(project/name,resources/name)
    shutil.copytree(project/'assets',resources/'assets',ignore=shutil.ignore_patterns('*.import','*.uid','.DS_Store'))
    with (stage/'Contents/Info.plist').open('wb') as file:
        plistlib.dump({'CFBundleName':'Forest Wanderer 0.1.5.11','CFBundleDisplayName':'Forest Wanderer 0.1.5.11','CFBundleIdentifier':'local.forestwanderer.v01511','CFBundleExecutable':'ForestWanderer01511','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.5.11','CFBundleVersion':'0.1.5.11','NSHighResolutionCapable':True},file)
    for attr in ['com.apple.FinderInfo','com.apple.ResourceFork']:
        subprocess.run(['xattr','-dr',attr,str(stage)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=False)
    subprocess.run(['codesign','--force','--deep','--sign','-',str(stage)],check=True)
    subprocess.run(['codesign','--verify','--deep','--strict',str(stage)],check=True)
    print('STAGING_STRICT_SIGNATURE_VERIFIED')
    target=project/stage.name
    # Replace the bundle directory instead of merging into Finder/FileProvider
    # metadata from a previously launched app. Preserve the previous package.
    if target.exists():
        previous=Path(tempfile.mkdtemp(prefix='previous-local-app-',dir=test))/stage.name
        target.rename(previous)
        print('PREVIOUS_PACKAGE',previous)
    shutil.copytree(stage,target)
    subprocess.run(['codesign','--verify','--deep',str(target)],check=True)
    print('LOCAL_SIGNATURE_VERIFIED')
    print('PACKAGED',target)
