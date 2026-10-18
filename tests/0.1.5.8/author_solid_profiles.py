"""Hand-traced visible solid silhouettes, with independent visual sample labels.

Pixel coordinates are from the 0.1.5.7 runtime-trimmed sprite previews. They
are converted to UV once so painting and collision share the runtime crop.
No alpha hull is used: plants, gaps, and the gate opening were inspected.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech')
SRC = ROOT / 'tests/0.1.5.7/profile-sprites'
DST = ROOT / 'tests/0.1.5.8/solid-profiles'
DST.mkdir(parents=True, exist_ok=True)
PROFILE = ROOT / 'output/adventure game 0.1.5.8/collision_profiles.json'
data = json.loads(PROFILE.read_text())
entries = {}

def add(key, sprite, polys, solids, passable, note):
    entries[key] = dict(sprite=sprite, polygons_px=polys,
                        solid_samples_px=solids, passable_samples_px=passable,
                        note=note)

house = [[(30,159),(75,139),(113,124),(107,105),(112,50),(114,29),
          (142,13),(169,6),(194,14),(222,25),(226,44),(225,82),
          (269,68),(316,55),(360,41),(408,27),(449,13),(459,31),
          (480,77),(489,116),(511,142),(530,180),(530,193),(503,204),
          (500,268),(502,310),(489,327),(482,368),(461,366),(459,394),
          (483,419),(485,447),(448,462),(396,480),(364,471),(345,438),
          (316,421),(294,418),(266,434),(231,420),(212,405),(213,393),
          (185,386),(139,362),(86,325),(65,301),(57,262),(54,205),(34,189)]]
hs = [('chimney upper',166,40),('chimney base',156,91),('left roof',83,157),
      ('roof centre',306,151),('roof upper right',419,59),('right roof edge',502,178),
      ('left wall',99,248),('side wall lower',169,350),('front wall left',265,330),
      ('door cannot enter',366,327),('front wall right',454,309),('top step',404,400),
      ('lower step',431,440),('lower left roof',240,267)]
hp = [('left outer foliage',27,336),('right outer foliage',538,372),
      ('front outer foliage',235,478),('above roof',349,12),('outside right wall',546,262)]
add('cabin','cabin',house,hs,hp,'Complete solid cabin: chimney, roof, both walls, closed door and both steps. There is no indoor scene. Outer decorative foliage stays passable.')
add('prop_0','prop_0',house,hs,hp,'Same complete closed cabin silhouette as cabin; no wall-only footprint.')

add('prop_1','prop_1', [[(74,58),(78,34),(91,19),(111,6),(142,18),(168,35),
                       (199,47),(227,64),(243,77),(256,103),(278,112),(293,127),
                       (299,150),(291,173),(277,184),(257,192),(226,195),(218,209),
                       (199,223),(175,216),(148,201),(124,188),(92,170),(66,153),
                       (46,146),(40,126),(49,108),(67,91),(84,83),(80,74)]],
    [('rear log',138,55),('rear cut end',218,98),('front log',113,138),
     ('front cut end',195,184),('right cut end',270,154),('upper log tip',112,19)],
    [('left flowers',24,173),('right flowers',329,201),('below front end',198,248)],
    'Whole three-log pile, including upper timber and both rounded cut faces; excludes foliage.')

add('prop_2','prop_2', [[(84,55),(93,30),(105,18),(122,8),(144,16),(181,32),
                       (218,55),(263,72),(292,87),(319,110),(345,123),(359,139),
                       (367,163),(359,190),(344,208),(324,214),(306,204),(281,199),
                       (270,222),(255,240),(239,246),(222,242),(205,230),(177,217),
                       (147,205),(114,185),(80,167),(54,155),(40,142),(45,121),
                       (52,104),(73,85),(98,91),(90,77)]],
    [('rear log upper',128,29),('rear timber',174,78),('rear cut face',269,117),
     ('right cut face',332,172),('front wood',141,164),('front cut face',239,204)],
    [('left low foliage',27,209),('right ground',385,255),('below timber',257,273)],
    'Long log pile full silhouette; each timber and exposed circular cut end is blocked.')

add('prop_3','prop_3', [[(75,70),(87,42),(109,25),(146,11),(181,7),(220,10),
                       (256,24),(276,39),(292,64),(298,97),(304,136),(304,169),
                       (298,206),(283,236),(267,260),(241,278),(205,285),(169,284),
                       (139,276),(113,265),(94,248),(79,224),(69,192),(63,160),
                       (64,117),(70,89)]],
    [('barrel lid',180,38),('left hoop',92,91),('barrel belly',178,164),
     ('right hoop',279,205),('barrel foot',198,271)],
    [('left flowers',31,230),('right flowers',338,246),('below barrel',196,306)],
    'Whole barrel, lid to rounded belly and bottom rim; no side entry through upper volume.')

add('prop_4','prop_4', [[(53,61),(80,48),(111,35),(153,20),(176,10),(198,9),
                       (232,25),(267,43),(298,61),(321,78),(319,116),(318,157),
                       (312,197),(294,215),(285,245),(260,254),(230,260),(204,272),
                       (177,280),(157,270),(141,242),(121,227),(98,212),(82,184),
                       (64,174),(55,140),(53,99)]],
    [('crate top back',190,33),('crate top left',102,67),('crate top front',234,92),
     ('left side',110,143),('right side',253,181),('front upright foot',180,251)],
    [('left flowers',21,212),('right flowers',348,232),('below crate',181,303)],
    'Full crate boards and uprights with hand-authored oblique edges; outside foliage excluded.')

add('prop_5','prop_5', [[(58,50),(88,40),(123,25),(155,10),(170,7),(188,14),
                       (224,33),(252,47),(274,56),(278,78),(276,110),(275,148),
                       (267,174),(247,192),(222,206),(194,214),(168,232),(149,229),
                       (131,213),(111,196),(90,183),(75,160),(60,149),(56,121),(57,82)]],
    [('grey crate top',165,51),('left panel',99,110),('right panel',218,139),
     ('far upright',264,100),('front upright foot',154,211)],
    [('left outside plants',23,165),('right outside plants',298,187),('bottom ground',213,233)],
    'Grey crate full body and top contour, separate from prop_4 silhouette.')

add('bench','bench', [[(33,150),(44,145),(43,111),(61,104),(87,113),(86,78),
                     (90,45),(112,39),(139,43),(147,65),(152,109),(270,107),
                     (291,106),(292,100),(312,98),(324,109),(399,104),(404,119),
                     (404,140),(406,177),(412,202),(415,240),(411,259),(386,264),
                     (378,293),(367,295),(368,320),(368,349),(351,356),(326,357),
                     (313,338),(310,310),(128,316),(125,345),(111,355),(83,350),
                     (80,334),(84,305),(83,280),(64,274),(54,262),(48,237),(45,205),
                     (41,172)]],
    [('left high post',119,74),('table left',61,165),('table centre',248,190),
     ('table right',392,226),('front apron',239,265),('under support board',225,292),
     ('left leg foot',105,333),('right leg foot',341,335)],
    [('left vegetation',16,281),('right vegetation',440,300),('under beam clear',223,344)],
    'Whole workbench top, rear post, apron, supporting beam and legs. Small side vegetation and below-beam gap remain open.')

add('stump_0','stump_0', [[(14,241),(9,231),(27,211),(59,201),(83,191),(99,172),
                         (113,145),(121,105),(130,66),(144,45),(170,33),(200,29),
                         (244,19),(266,20),(289,36),(304,36),(326,28),(348,40),
                         (356,65),(358,96),(358,134),(371,166),(395,177),(424,186),
                         (452,207),(466,222),(459,237),(434,241),(407,231),(383,227),
                         (380,254),(394,274),(411,303),(412,319),(398,325),(377,320),
                         (351,301),(320,296),(291,279),(267,252),(252,236),(233,242),
                         (213,262),(192,265),(170,284),(152,287),(130,307),(110,315),
                         (93,306),(89,291),(102,271),(119,248),(127,232),(98,240),
                         (68,237),(43,249),(28,249)]],
    [('stump cut surface',232,103),('left upper bark',140,87),('right upper bark',343,104),
     ('front bark',257,196),('left lateral root',43,226),('left long root',117,288),
     ('right lateral root',437,215),('right long root',388,303)],
    [('left foliage',31,133),('right foliage',430,130),('bottom foliage',199,326)],
    'Entire visible woody stump, cut top, bark, and all long irregular roots; leaves outside wood excluded.')

add('stump_1','stump_1', [[(63,305),(61,290),(73,272),(100,260),(117,241),
                         (123,210),(120,177),(120,139),(123,121),(138,99),(154,81),
                         (175,51),(197,32),(222,21),(231,20),(244,42),(249,22),
                         (262,10),(278,8),(289,29),(289,54),(282,80),(282,106),
                         (286,143),(294,174),(308,198),(333,212),(361,224),(384,240),
                         (394,257),(390,268),(367,266),(345,254),(326,247),(321,264),
                         (335,287),(346,312),(345,324),(332,330),(316,322),(294,311),
                         (272,294),(250,266),(227,240),(205,256),(189,265),(166,266),
                         (146,288),(121,300),(97,317),(80,318)]],
    [('broken rim highest',268,32),('left broken wood',205,48),('upright bark',242,147),
     ('left root',83,291),('right horizontal root',371,247),('right low root',323,308)],
    [('left plant',49,203),('right plant',338,139),('below roots',212,332)],
    'Whole broken stump including high splintered bark and both protruding lateral roots.')

add('ore_0','ore_0', [[(111,172),(117,141),(127,118),(153,101),(175,81),
                      (203,70),(240,61),(276,52),(303,42),(325,38),(341,47),
                      (355,72),(365,96),(370,126),(380,147),(387,174),(383,196),
                      (371,215),(351,222),(335,240),(312,247),(291,256),(267,249),
                      (243,239),(226,220),(204,199),(170,181),(139,175)],
                     [(51,255),(52,232),(67,207),(86,189),(105,179),(123,174),
                      (145,180),(170,192),(188,210),(198,240),(199,257),(184,276),
                      (163,287),(142,287),(128,277),(106,279),(83,267),(66,271)]],
    [('big ore top',325,53),('big ore centre',273,155),('big ore right edge',371,171),
     ('big ore low face',290,236),('small ore top',122,191),('small ore foot',153,269)],
    [('left plants',39,181),('right plants',412,219),('lower gap foliage',233,277)],
    'Two complete exposed ore rocks, including upper peaks and side faces; leafy exterior excluded.')

add('ore_1','ore_1', [[(89,198),(100,167),(113,133),(129,104),(142,75),
                      (153,50),(176,28),(192,17),(207,14),(227,27),(244,53),
                      (259,76),(269,105),(280,124),(298,133),(310,154),(323,180),
                      (331,212),(340,242),(349,271),(344,288),(327,292),(305,279),
                      (283,271),(267,279),(246,256),(232,234),(202,221),(177,215),
                      (150,207),(120,202)],
                     [(29,290),(27,267),(35,244),(47,228),(63,214),(82,205),
                      (103,201),(123,207),(144,221),(158,230),(169,252),(181,276),
                      (187,300),(176,315),(158,318),(143,328),(122,329),(103,318),
                      (89,312),(78,302),(57,303),(42,297)]],
    [('peak exposed',204,32),('big ore left',127,158),('big ore centre',221,166),
     ('big ore right low',319,246),('small ore upper',96,220),('small ore foot',129,312)],
    [('left outside foliage',31,177),('right outside foliage',390,239),('bottom outside',231,343)],
    'Complete tall ore peak and independent foreground stone, no thin lower-foot-only barriers.')

add('ore_2','ore_2', [[(131,173),(138,149),(148,131),(173,117),(199,103),
                      (226,82),(247,80),(273,89),(294,104),(315,122),(336,137),
                      (352,151),(363,175),(364,199),(351,219),(331,235),(310,242),
                      (290,259),(268,263),(243,249),(223,234),(206,213),(184,193),
                      (159,182)],
                     [(59,231),(59,214),(75,191),(87,180),(103,176),(123,178),
                      (143,185),(161,193),(183,204),(193,224),(199,245),(194,261),
                      (178,274),(156,280),(136,279),(119,269),(101,263),(85,248),
                      (72,238)]],
    [('broad ore top',243,92),('large ore centre',266,173),('large ore right',342,188),
     ('large ore bottom',269,244),('small ore top',107,193),('small ore bottom',153,263)],
    [('upper plants',333,60),('left plants',25,212),('below rock plants',217,279)],
    'Full broad ore mound and foreground stone; grey material counts as solid at every height.')

add('gate','gate', [[(116,71),(127,49),(141,36),(166,27),(186,29),(199,45),
                   (203,73),(197,100),(191,123),(194,151),(194,178),(190,202),
                   (178,218),(180,241),(162,260),(146,267),(132,286),(126,300),
                   (110,310),(91,313),(69,307),(51,291),(49,271),(64,252),
                   (85,241),(99,238),(99,216),(85,201),(83,177),(85,149),(91,132),
                   (112,111),(112,90)],
                  [(220,54),(232,37),(255,27),(277,31),(301,40),(310,55),
                   (308,76),(322,91),(350,96),(365,112),(376,135),(376,155),
                   (366,175),(359,183),(375,197),(379,220),(375,245),(368,260),
                   (374,287),(367,310),(381,326),(396,341),(395,355),(381,364),
                   (362,365),(342,358),(329,354),(317,351),(316,335),(327,320),
                   (322,300),(307,280),(289,267),(287,240),(286,216),(284,198),
                   (288,178),(283,150),(280,125),(269,111),(249,105),(231,94),
                   (217,78)]],
    [('left upper stone',158,72),('left mid stone',127,171),('left lower stone',132,228),
     ('left foot rock',91,275),('right upper stone',259,61),('right high pillar',340,141),
     ('right lower pillar',330,231),('right foot rock',357,341)],
    [('gate opening upper',239,156),('gate opening centre',242,221),
     ('gate opening lower',249,289),('left outer flowers',25,225),('right outer flowers',434,296)],
    'Both complete irregular masonry sides and individual foot rocks. The central arch opening stays traversable; overhead greenery is not a solid.')

# Dry shore stones are deliberately separate from the retained water mask.
# Include each small isolated rock as well as every large shoreline boulder.
add('pond_0_rocks','pond_0', [
    [(63,146),(67,136),(80,126),(93,126),(106,132),(113,142),(110,150),(102,158),(91,162),(76,158),(63,153)],
    [(160,70),(166,51),(181,36),(198,29),(215,28),(232,38),(242,52),(251,67),(251,76),(238,79),(226,89),(210,91),(194,85),(179,91),(166,83)],
    [(393,101),(397,92),(409,86),(416,89),(419,97),(414,106),(408,111),(400,107)],
    [(410,120),(408,109),(417,98),(433,87),(452,86),(469,93),(485,103),(494,114),(500,133),(490,143),(474,146),(456,151),(441,149),(427,141)],
    [(52,310),(54,296),(62,283),(82,274),(99,268),(114,274),(131,286),(140,303),(144,317),(132,329),(114,335),(96,331),(85,324),(68,324)],
    [(200,358),(197,349),(207,340),(219,336),(232,341),(240,350),(245,356),(238,363),(225,366),(211,362)],
    [(358,365),(357,352),(366,340),(380,330),(397,324),(412,328),(428,341),(437,356),(439,369),(427,377),(409,382),(393,378),(379,376),(365,374)]],
    [('left isolated rock',87,143),('top boulder',210,55),('top small right stone',405,98),
     ('right boulder',461,120),('left bottom boulder',96,300),('bottom small stone',220,352),
     ('bottom right boulder',398,350)],
    [('left shore grass gap',40,213),('right upper outer grass',542,148),
     ('lower grass between stones',306,363),('above top stone',206,8)],
    'Seven independently drawn shore-rock solids: top, upper-right small, upper-right large, left small, left low, bottom small, bottom-right. Separate from retained water.')

add('pond_1_rocks','pond_1', [
    [(191,89),(191,79),(201,67),(213,60),(224,63),(231,70),(236,83),(234,92),(223,97),(208,95),(198,92)],
    [(395,116),(398,99),(410,85),(430,71),(450,63),(468,61),(486,67),(500,81),(508,97),(514,115),(509,130),(498,140),(481,148),(462,145),(442,140),(426,137),(406,132)],
    [(36,253),(36,242),(45,231),(57,226),(70,229),(80,239),(88,248),(87,258),(75,265),(61,264),(47,260)],
    [(72,324),(78,308),(87,290),(105,280),(126,276),(145,277),(162,287),(173,302),(181,318),(184,331),(172,340),(152,345),(134,343),(117,337),(97,340),(82,333)],
    [(188,351),(191,340),(204,331),(218,332),(230,341),(235,351),(231,361),(219,366),(207,364),(196,359)]],
    [('top small stone',214,79),('right top boulder',456,102),('left small stone',60,245),
     ('left lower boulder',132,308),('lower small stone',213,348)],
    [('top right outer shore',545,61),('lower outer shore',293,388),('upper grass bank',339,45)],
    'Five separate complete visible shore rocks. Each upper/side face and each tiny stone is solid; green bank remains passable.')

add('pond_2_rocks','pond_2', [
    [(30,305),(32,290),(42,273),(60,257),(82,249),(103,250),(120,260),(136,272),(142,288),(150,308),(148,319),(135,329),(116,333),(99,329),(81,326),(63,329),(45,323)],
    [(269,359),(273,344),(288,332),(306,321),(326,319),(339,326),(348,339),(353,354),(354,367),(342,376),(322,381),(303,377),(289,374),(276,370)],
    [(360,203),(360,191),(372,180),(387,170),(403,167),(418,173),(428,183),(436,196),(440,210),(432,217),(417,223),(403,222),(388,219),(373,215)],
    [(304,174),(307,167),(317,162),(326,162),(334,168),(338,174),(332,179),(322,184),(311,182),(304,178)],
    [(356,236),(358,231),(365,228),(374,229),(381,233),(385,238),(380,241),(372,244),(363,242),(357,240)]],
    [('left shore boulder',87,290),('bottom shore boulder',315,353),('right shore boulder',402,197),
     ('small upper water stone',322,172),('small lower water stone',370,236)],
    [('top left grass',42,121),('below left gap ground',221,364),('outer right grass',458,233)],
    'Three large bank rocks plus both small water stones have distinct solids. Entire visible grey rock, not just lower base, is blocked.')

# Small collectible stones also block their exposed upper and lateral faces.
add('resource_rock_0','resource_rock_0', [
    [(37,140),(40,114),(51,82),(65,51),(88,29),(110,16),(137,8),(158,15),(178,36),(190,62),(199,86),(211,118),(206,143),(185,166),(163,168),(139,169),(113,169),(87,163),(61,162),(46,153)],
    [(143,174),(148,153),(160,137),(178,125),(197,119),(212,123),(228,133),(239,149),(243,170),(236,188),(220,191),(204,187),(187,191),(170,189),(155,182)]],
    [('big rock top',151,38),('big rock middle',110,90),('big rock side',178,112),
     ('small stone',199,154)],
    [('right foliage',252,94),('lower outside plants',133,199)],
    'Complete collectible main boulder and small foreground stone; visible solid upper faces now covered.')

add('resource_rock_1','resource_rock_1', [
    [(34,163),(36,139),(45,111),(55,83),(71,64),(93,50),(115,52),(130,65),(139,91),(145,123),(143,151),(130,167),(108,177),(89,178),(69,177),(52,171)],
    [(98,190),(100,173),(112,158),(128,149),(145,146),(165,151),(178,164),(187,180),(190,195),(182,207),(165,211),(145,211),(131,206),(116,207),(104,200)]],
    [('main upper stone',99,70),('main grey face',94,129),('small stone',151,173)],
    [('upper right plant',172,65),('left plants',13,125)],
    'Complete tall grey collectible stone and its separate lower foreground stone.')

add('resource_rock_2','resource_rock_2', [
    [(63,126),(69,100),(84,73),(96,49),(116,24),(137,8),(151,7),(175,17),(192,37),(207,64),(220,95),(225,118),(221,142),(205,159),(184,167),(160,170),(138,168),(113,158),(92,145),(75,138)],
    [(26,177),(26,159),(38,140),(49,125),(65,113),(85,109),(101,113),(119,124),(135,139),(145,159),(149,177),(145,189),(129,198),(110,199),(91,193),(69,196),(51,187),(36,188)]],
    [('large top grey',152,21),('large right side',197,86),('large centre',147,117),
     ('small front rock',88,153)],
    [('outer right leaves',248,107),('outer bottom green',190,193)],
    'Full broad collectible grey rocks, including the peak, shoulder, and foreground stone.')

add('resource_rock_spent_0','resource_rock_spent_0', [
    [(7,115),(10,101),(20,91),(34,84),(47,82),(58,89),(72,99),(77,113),(69,124),(55,129),(39,128),(25,127),(13,122)],
    [(74,107),(79,85),(91,69),(107,59),(122,58),(139,65),(153,81),(160,98),(157,111),(143,123),(125,128),(111,124),(92,121),(81,117)],
    [(153,120),(155,106),(168,95),(181,90),(196,93),(206,104),(211,116),(207,126),(195,133),(178,135),(162,130)]],
    [('left remnant',41,108),('middle remnant',120,87),('right remnant',184,114)],
    [('upper right leaves',213,69),('low left bank',11,140)],
    'Three independently outlined remaining solid stones; removed decorative foliage and retained actual stone gaps.')

add('resource_rock_spent_1','resource_rock_spent_1', [
    [(75,51),(79,34),(92,19),(105,10),(120,10),(133,19),(143,33),(145,46),(137,58),(124,67),(109,66),(93,62),(81,60)],
    [(37,103),(40,87),(52,72),(71,62),(89,58),(108,64),(125,75),(138,87),(143,101),(139,113),(128,121),(110,128),(89,126),(71,122),(57,120),(45,113)]],
    [('upper remnant',111,36),('lower remnant',89,90)],
    [('left outside plants',20,75),('right outside plants',199,91)],
    'Both full visible depleted stones rather than cropped lower contact patches.')

add('resource_rock_spent_2','resource_rock_spent_2', [
    [(42,117),(43,103),(52,86),(65,72),(80,63),(96,62),(111,69),(122,82),(132,98),(130,112),(119,124),(105,132),(88,132),(70,128),(54,128)],
    [(123,127),(124,115),(134,105),(146,97),(159,94),(170,101),(177,113),(181,125),(175,135),(163,142),(149,143),(136,137)],
    [(69,156),(71,146),(83,137),(97,132),(111,136),(122,147),(124,160),(116,170),(104,175),(91,171),(77,167)]],
    [('upper left remnant',90,91),('right remnant',151,118),('bottom remnant',98,152)],
    [('upper right plants',195,82),('lower left leaves',39,143)],
    'Three complete surviving stones, separately traced with open surrounding green ground.')

# Exposed bark is also a solid. Retain each original irregular root contour
# and its depth anchor, then union only the visible trunk and large branches.
# Empty branch gaps and foliage are intentionally absent from these contours.
root_reference=json.loads((ROOT/'output/adventure game 0.1.5.7/collision_profiles.json').read_text())
def add_tree(key, bark_polygons, solid_samples, canopy_samples):
    w,h=Image.open(SRC/(key+'.png')).size
    roots=[[(x*w,y*h) for x,y in p] for p in root_reference[key]['polygons']]
    add(key,key,roots+bark_polygons,solid_samples,canopy_samples,
        'Original measured root footprint and unchanged root depth, plus independently traced visible wood: trunk, exposed fork and large branches. Foliage canopy and empty gaps remain passable; no whole-canopy collision.')
    entries[key]['depth_v_override']=root_reference[key]['depth_v']

add_tree('tree_0', [[(267,217),(279,210),(287,232),(284,252),(288,258),
                    (303,240),(311,222),(324,219),(329,232),(320,251),(309,270),
                    (298,286),(316,281),(319,294),(308,304),(304,324),(301,345),
                    (306,362),(322,350),(338,334),(343,319),(355,313),(361,326),
                    (372,323),(388,308),(395,304),(389,325),(374,346),(357,357),
                    (343,377),(321,391),(310,414),(310,445),(318,464),(316,475),
                    (303,477),(294,464),(281,468),(266,461),(254,447),(245,434),
                    (231,432),(216,441),(206,438),(209,415),(213,395),(211,386),
                    (195,372),(179,360),(169,344),(151,335),(152,327),(172,331),
                    (180,330),(182,321),(178,307),(174,296),(181,283),(193,295),
                    (198,313),(204,322),(217,322),(215,306),(209,295),(210,286),
                    (223,285),(228,293),(237,305),(242,321),(249,300),(259,280),
                    (270,260),(263,241),(264,225)]],
    [('upper left exposed wood',275,233),('upper right fork',311,244),
     ('middle trunk',277,317),('left diagonal branch',183,344),
     ('left upward twig',184,307),('right branch',347,359),
     ('right thin branch',382,326),('lower bark',280,437)],
    [('upper green canopy',287,59),('left teal canopy',80,156),
     ('right teal canopy',423,274),('left green canopy',127,205),
     ('gap between right forks',356,284)])

add_tree('tree_1', [[(197,361),(205,365),(208,380),(216,393),(216,408),
                    (228,422),(235,436),(242,444),(229,450),(216,442),
                    (216,454),(206,451),(203,439),(193,445),(183,453),
                    (178,443),(175,433),(183,416),(185,402),(190,385),(188,374)]],
    [('exposed upper pine bark',198,378),('pine trunk centre',202,408),
     ('pine lower bark',210,431),('left root wood',189,434)],
    [('pine top foliage',206,60),('pine middle foliage',170,231),
     ('pine left low canopy',93,381),('pine right low canopy',309,403)])

add_tree('tree_2', [[(147,466),(154,443),(163,420),(168,390),(178,361),
                    (191,324),(197,303),(201,284),(198,266),(189,251),(184,247),
                    (185,241),(191,240),(199,251),(207,268),(212,264),(219,244),
                    (230,220),(235,192),(240,171),(234,160),(231,137),(237,134),
                    (241,137),(243,156),(248,157),(254,145),(260,128),(267,119),
                    (275,120),(272,133),(271,146),(278,148),(287,138),(299,133),
                    (306,138),(299,145),(284,155),(266,165),(255,177),(250,193),
                    (247,213),(253,219),(247,236),(239,259),(234,276),(249,274),
                    (269,264),(283,257),(296,248),(305,247),(308,251),(296,262),
                    (286,272),(271,281),(250,293),(236,304),(231,322),(224,345),
                    (221,357),(235,351),(248,334),(258,336),(257,347),(244,360),
                    (225,373),(212,383),(209,410),(204,442),(199,466),(186,470),
                    (173,478),(154,477)],
                   [(169,315),(175,309),(181,320),(181,339),(193,352),
                    (193,369),(183,373),(177,358),(168,348),(164,325)]],
    [('left top birch fork',238,151),('top pale twig',266,134),
     ('upper right twig',291,143),('high trunk',240,209),
     ('left thin branch',197,258),('right pale branch',276,272),
     ('trunk middle',212,317),('lower bark',184,421),
     ('right dark branch',242,352),('left rear dark branch',175,337)],
    [('upper leaf crown',303,64),('left upper leaves',161,142),
     ('right leaf crown',353,260),('left teal leaves',100,282),
     ('right low leaves',254,448)])

add_tree('tree_3', [[(231,183),(240,178),(242,193),(251,189),(255,195),
                    (250,211),(257,212),(257,220),(250,230),(246,248),(246,259),
                    (259,263),(278,254),(296,245),(311,244),(307,252),(305,265),
                    (309,272),(301,282),(276,298),(263,317),(264,339),(268,366),
                    (264,377),(252,373),(240,373),(222,378),(204,376),(198,369),
                    (186,374),(171,370),(174,351),(177,328),(180,310),(173,291),
                    (151,276),(137,263),(124,251),(118,235),(126,230),(137,239),
                    (157,243),(171,248),(168,227),(166,209),(174,203),(178,213),
                    (185,204),(193,205),(192,216),(182,229),(184,244),(194,263),
                    (201,277),(211,248),(216,231),(219,219),(227,216),(231,203),
                    (226,196),(231,187)]],
    [('highest exposed fork',235,194),('middle bark',226,270),
     ('left upward branch',174,223),('left diagonal branch',146,253),
     ('right diagonal branch',282,277),('lower bark',233,341)],
    [('top green leaf crown',264,63),('left green canopy',84,149),
     ('right teal canopy',349,174),('right lower leaves',358,284),
     ('left dark canopy',95,280)])

add_tree('tree_4', [[(161,355),(168,343),(172,332),(178,340),(181,355),
                    (184,372),(184,397),(183,421),(183,442),(172,449),
                    (157,448),(143,449),(130,448),(120,441),(124,429),
                    (126,416),(134,397),(138,380),(143,362),(150,365),(154,356)]],
    [('upper pine bark',173,351),('middle pine bark',165,383),
     ('left exposed wood',138,411),('lower pine bark',164,433)],
    [('pine top',168,53),('pine middle foliage',158,169),
     ('left low canopy',65,367),('right low canopy',251,408)])

add_tree('tree_5', [[(194,128),(205,130),(208,143),(214,151),(215,163),
                    (223,174),(235,173),(243,177),(242,188),(235,199),(227,211),
                    (223,236),(220,260),(221,283),(224,312),(230,327),(241,301),
                    (250,282),(261,259),(272,237),(284,215),(306,189),(317,192),
                    (313,208),(301,228),(289,249),(288,258),(304,252),(318,238),
                    (328,238),(334,248),(351,247),(358,252),(347,263),(328,272),
                    (305,283),(282,294),(267,305),(257,324),(247,344),(242,365),
                    (241,385),(242,418),(244,441),(245,454),(237,455),(221,453),
                    (211,454),(196,454),(190,444),(188,420),(187,397),(184,379),
                    (170,367),(150,356),(130,340),(115,324),(101,316),(108,306),
                    (122,311),(135,313),(141,311),(136,294),(132,277),(137,261),
                    (144,261),(147,280),(151,294),(161,309),(174,323),(190,339),
                    (199,343),(201,327),(197,304),(184,286),(177,271),(171,255),
                    (172,245),(180,247),(185,265),(190,271),(195,270),(197,244),
                    (201,221),(206,201),(209,195),(205,186),(201,179),
                    (199,173),(200,166),(196,160),(194,151),(192,142),(190,134)]],
    [('high left bark twig',204,151),('upper left fork outer bark',203,174),
     ('trunk below first fork',216,218),
     ('left upward bark',142,287),('left diagonal branch',163,332),
     ('left middle twig',183,271),('right upper bark twig',300,210),
     ('right side bark twig',323,258),('right diagonal bark',265,296),
     ('central main bark',219,353),('lower main bark',217,424)],
    [('top yellow crown',194,94),('left teal crown',57,176),
     ('right yellow crown',315,161),('right leaf beside branch',369,232),
     ('left low yellow leaves',72,275),
     ('right low teal leaves',284,383)])

def contains(p, poly):
    x,y=p; hit=False
    for i,a in enumerate(poly):
        b=poly[(i+1)%len(poly)]
        if (a[1]>y)!=(b[1]>y):
            if x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]: hit=not hit
    return hit

coverage = {'source':'Independent hand-picked visual material labels on runtime-trimmed sprites; samples are not generated from polygons.',
            'policy':'Full visible solid rock/wood/building body, plants excluded. Trees retain trunk/root collision and overhead canopy passage. Gate opening passable.',
            'profiles':{}, 'failures':[]}
try: font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',16)
except OSError: font=ImageFont.load_default()
for key,e in entries.items():
    img=Image.open(SRC / (e['sprite']+'.png')).convert('RGBA'); w,h=img.size
    polys=[[[round(x/w,5),round(y/h,5)] for x,y in poly] for poly in e['polygons_px']]
    depth=e.get('depth_v_override',max(y for poly in polys for x,y in poly))
    data[key]={'polygons':polys,'depth_v':depth,'notes':e['note']}
    visual=Image.new('RGBA',img.size,(211,220,194,255));visual.alpha_composite(img)
    outline=Image.new('RGBA',img.size);draw=ImageDraw.Draw(outline)
    for i,poly in enumerate(e['polygons_px']):
        draw.polygon(poly,fill=(250,75,41,55));draw.line(poly+[poly[0]],fill=(238,35,24,255),width=2)
    visual.alpha_composite(outline)
    # Upscale annotation for legible point numbers; gameplay sprites unchanged.
    scale=max(1,760//max(w,h));visual=visual.resize((w*scale,h*scale))
    draw=ImageDraw.Draw(visual)
    solid_samples=[];passable_samples=[]
    for idx,(label,x,y) in enumerate(e['solid_samples_px']):
        ok=any(contains((x,y),p) for p in e['polygons_px'])
        solid_samples.append({'label':label,'uv':[round(x/w,5),round(y/h,5)],'pixel':[x,y],'covered':ok})
        if not ok:coverage['failures'].append({'profile':key,'sample':label,'kind':'missing solid'})
        px,py=x*scale,y*scale;draw.ellipse((px-4,py-4,px+4,py+4),fill=(255,30,25));draw.text((px+5,py-9),str(idx+1),font=font,fill=(255,255,255),stroke_width=2,stroke_fill=(60,10,5))
    for idx,(label,x,y) in enumerate(e['passable_samples_px']):
        ok=not any(contains((x,y),p) for p in e['polygons_px'])
        passable_samples.append({'label':label,'uv':[round(x/w,5),round(y/h,5)],'pixel':[x,y],'passable':ok})
        if not ok:coverage['failures'].append({'profile':key,'sample':label,'kind':'blocked passable'})
        px,py=x*scale,y*scale;draw.ellipse((px-4,py-4,px+4,py+4),fill=(30,248,70));draw.text((px+5,py-9),'P'+str(idx+1),font=font,fill=(255,255,255),stroke_width=2,stroke_fill=(0,60,15))
    visual.convert('RGB').save(DST/(key+'-annotated.png'))
    coverage['profiles'][key]={'sprite':e['sprite'],'size':[w,h],'polygon_count':len(polys),
                               'solid_samples':solid_samples,'passable_samples':passable_samples,
                               'note':e['note'],'overlay':str(DST/(key+'-annotated.png'))}

PROFILE.write_text(json.dumps(data,indent=2)+'\n')
(ROOT/'tests/0.1.5.8/solid-profiles-coverage.json').write_text(json.dumps(coverage,indent=2)+'\n')
print('Updated',len(entries),'full solid profiles;',sum(len(e['solid_samples_px']) for e in entries.values()),'independent solid samples;',sum(len(e['passable_samples_px']) for e in entries.values()),'passable samples.')
print('Visual coverage failures:',coverage['failures'])
assert not coverage['failures']
