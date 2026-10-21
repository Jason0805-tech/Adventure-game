from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[3]; p=root/'output/adventure game 0.1.5.1';g=Path('/Users/jasonsmacair/.codex/generated_images/01a12370-5b35-7eb2-809e-f354f97a3872')
for name,key in [('step-pass-a','672ac0af-37af-460a-82f7-756ceea7c3a6'),('step-contact-b','a962269e-a5ad-4f12-92eb-55aee80c42ab'),('step-pass-b','c667a80a-5489-43f8-9c89-e5d6702b76ad')]:shutil.copyfile(g/('exec-'+key+'.png'),p/'assets'/(name+'.png'))
