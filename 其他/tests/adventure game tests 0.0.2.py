import ast, contextlib, hashlib, importlib.util, io, json, runpy, sys
from pathlib import Path
from unittest.mock import patch

SOURCE = Path('/Users/jasonsmacair/Library/Mobile Documents/com~apple~CloudDocs/Downloads/学习/高中BASIS/ap CSP/adventure game program by AI tech/adventure game 0.0.2.py')
spec = importlib.util.spec_from_file_location('forest_game', SOURCE)
game = importlib.util.module_from_spec(spec)
spec.loader.exec_module(game)
results = []
covered = set()
def tracer(frame, event, arg):
    if event == 'line' and frame.f_code.co_filename == str(SOURCE):
        covered.add(frame.f_lineno)
    return tracer

def case(name, category, answers, function, args=(), check=lambda r, o: True):
    output = io.StringIO()
    entries = iter(answers)
    def provide(prompt=''):
        value = next(entries)
        print(prompt + str(value))
        if isinstance(value, BaseException):
            raise value
        return value
    status, error = '通过', ''
    result = None
    try:
        with patch('builtins.input', side_effect=provide), contextlib.redirect_stdout(output):
            sys.settrace(tracer)
            result = function(*args)
            sys.settrace(None)
        assert check(result, output.getvalue()), '结果与预期不符'
        assert next(entries, None) is None, '部分测试输入没有被使用'
    except Exception as exc:
        status, error = '失败', repr(exc)
    finally:
        sys.settrace(None)
    results.append(dict(name=name, category=category, status=status, error=error, log=output.getvalue(), result=repr(result)))

case('文字、小数、负数输入后恢复', '材料收集', ['abc','1.5','-1','2'], game.read_amount, ('Amount: ',), lambda r,o:r==2)
case('超容量后重新选择，刚好装满10件', '材料收集', ['11','0','0','3','4','3'], game.collection, (0,0,0), lambda r,o:r==(3,4,3))
case('已有材料计入容量，允许全部输入0', '材料收集', ['1','0','0','0','0','0'], game.collection, (3,4,3), lambda r,o:r==(3,4,3))
for name, recipe in game.RECIPES.items():
    b,r,g,p = recipe
    case('制作 '+name, '武器制作', [name], game.weapon_craft, (b,r,g,0,[]), lambda x,o,p=p,name=name:x==(0,0,0,p,[name]))
case('材料不足、名称错误、取消制作', '武器制作', ['large stone sword','unknown','cancel'], game.weapon_craft, (0,0,0,0,[]), lambda r,o:r==(0,0,0,0,[]))
case('缺少大石剑时拒绝升级', '武器升级', ['amazing stone sword','cancel'], game.weapon_craft, (0,1,0,0,[]), lambda r,o:r==(0,1,0,0,[]))
case('缺少石头时拒绝升级', '武器升级', ['amazing stone sword','cancel'], game.weapon_craft, (0,0,0,4,['large stone sword']), lambda r,o:r==(0,0,0,4,['large stone sword']))
case('升级只消耗1块石头并替换武器', '武器升级', [' AMAZING STONE SWORD '], game.weapon_craft, (2,1,2,4,['large stone sword']), lambda r,o:r==(2,0,2,5,['amazing stone sword']))
for value, expected in [(0,'starving'),(1,'uncomfortable'),(20,'uncomfortable'),(21,'You are hungry.'),(40,'You are hungry.'),(41,'soon'),(60,'soon'),(61,'well fed'),(100,'well fed')]:
    case(f'饱食度边界 {value}', '饱食度', [], game.food_check, (value,), lambda r,o,e=expected:e in r)
case('空背包显示', '背包与菜单', [], game.show_bag, (0,0,0,0,100,[],[]), lambda r,o:'Weapons: none' in o and 'Special items: none' in o)
case('菜单错误输入与大小写容错', '背包与菜单', ['???',' BAG ',' CONTINUE '], game.preparation, (0,0,0,0,100,[],[]), lambda r,o:r==(0,0,0,0,[]))
case('三晚通关：制作、升级、探索、休息、背包', '完整试玩', ['collect','3','4','3','craft','large stone sword','bag','continue','rest','collect','0','1','0','craft','amazing stone sword','continue','explore','bag','continue','rest'], game.main, check=lambda r,o:'YOU WIN!' in o and 'Fullness: 0/100' in o and 'Power: 8' in o)
case('三晚通关：魔法石与药品消耗、觅食', '完整试玩', ['continue','explore','continue','look for food','continue','explore'], game.main, check=lambda r,o:o.count('magic stone saves you')==2 and o.count('using medicine')==1 and 'YOU WIN!' in o)
case('失败结局：错误行动不重复扣饱食度', '完整试玩', ['continue','invalid','rest'], game.main, check=lambda r,o:'Fullness: 65/100' in o and 'GAME OVER' in o and 'YOU WIN!' not in o)
case('战力刚好达标也能存活', '完整试玩', ['collect','2','2','1','craft','short stone knife','continue','rest','continue','rest'], game.main, check=lambda r,o:'You survived NIGHT 1!' in o and 'GAME OVER' in o)
for exception in [EOFError(), KeyboardInterrupt()]:
    case(type(exception).__name__+' 正常退出', '退出处理', [exception], lambda:runpy.run_path(str(SOURCE), run_name='__main__'), check=lambda r,o:'Game closed' in o)
# Python executable lines, including top-level setup and entrypoint, come from code objects.
import types
lines=set()
def collect(code):
    lines.update(line for _,_,line in code.co_lines() if line and line>0)
    for constant in code.co_consts:
        if isinstance(constant, types.CodeType): collect(constant)
collect(compile(SOURCE.read_text(),str(SOURCE),'exec'))
report = dict(version='0.0.2', source=str(SOURCE), sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(), results=results, passed=sum(r['status']=='通过' for r in results), total=len(results), executed_lines=len(lines & covered), executable_lines=len(lines), missing_lines=sorted(lines-covered))
Path(__file__).with_name('test-results-0.0.2.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ('results','source','sha256')},ensure_ascii=False))
for r in results:
    if r['status']!='通过': print(r)
