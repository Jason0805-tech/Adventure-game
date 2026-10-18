extends RefCounted
const Data=preload("res://item_data.gd")
const SLOT_COUNT=24
var slots:Array[Dictionary]=[]
var next_uid:int=1
func _init():
 for i in range(SLOT_COUNT):slots.append({})
func count(id:String)->int:
 var total:int=0
 for item in slots:
  if item.get("id","")==id:total+=int(item.qty)
 return total
func used_slots()->int:
 var total:int=0
 for item in slots:
  if not item.is_empty():total+=1
 return total
func index_of_uid(uid:int)->int:
 if uid<0:return -1
 for i in range(slots.size()):
  if int(slots[i].get("uid",-1))==uid:return i
 return -1
func first(id:String)->int:
 for i in range(slots.size()):
  if slots[i].get("id","")==id:return i
 return -1
func item_by_uid(uid:int)->Dictionary:
 var i:int=index_of_uid(uid)
 return slots[i] if i>=0 else {}
func add(id:String,quantity:int=1)->int:
 var spec:Dictionary=Data.info(id)
 if spec.is_empty() or quantity<=0:return 0
 var remaining:int=quantity
 var limit:int=int(spec.stack)
 if limit>1:
  for item in slots:
   if item.get("id","")==id:
    var amount:int=mini(limit-int(item.qty),remaining)
    item.qty+=amount;remaining-=amount
    if remaining==0:return quantity
 for i in range(slots.size()):
  if slots[i].is_empty():
   var amount:int=mini(limit,remaining)
   var item:Dictionary={"id":id,"qty":amount,"uid":next_uid}
   next_uid+=1
   if spec.has("durability"):item["durability"]=int(spec.durability)
   slots[i]=item;remaining-=amount
   if remaining==0:break
 return quantity-remaining
func remove(id:String,quantity:int)->bool:
 if quantity<0 or count(id)<quantity:return false
 var remaining:int=quantity
 for i in range(slots.size()):
  if slots[i].get("id","")==id:
   var amount:int=mini(int(slots[i].qty),remaining)
   slots[i].qty-=amount;remaining-=amount
   if slots[i].qty==0:slots[i]={}
   if remaining==0:break
 return true
func remove_uid(uid:int,quantity:int=1)->bool:
 var i:int=index_of_uid(uid)
 if i<0 or quantity<=0 or int(slots[i].qty)<quantity:return false
 slots[i].qty-=quantity
 if int(slots[i].qty)==0:slots[i]={}
 return true
func set_total(id:String,quantity:int)->void:
 var current:int=count(id)
 if quantity>current:add(id,quantity-current)
 elif quantity<current:remove(id,current-maxi(0,quantity))
func clone():
 var trial=get_script().new()
 trial.slots=slots.duplicate(true);trial.next_uid=next_uid
 return trial
func can_pay(cost:Dictionary)->bool:
 for id in cost:
  if count(id)<int(cost[id]):return false
 return true
func craft(cost:Dictionary,output:String,upgrade:String="")->Dictionary:
 if not Data.ITEMS.has(output) or not can_pay(cost):return {}
 var trial=clone()
 var base_index:int=-1
 if not upgrade.is_empty():
  base_index=trial.first(upgrade)
  if base_index<0:return {}
 for id in cost:trial.remove(id,int(cost[id]))
 var uid:int=-1
 if base_index>=0:
  var spec:Dictionary=Data.info(output)
  var old_uid:int=int(trial.slots[base_index].uid)
  trial.slots[base_index]={"id":output,"qty":1,"uid":old_uid,"durability":int(spec.durability)}
  uid=old_uid
 else:
  var before:int=trial.next_uid
  if trial.add(output,1)!=1:return {}
  uid=before
 slots=trial.slots;next_uid=trial.next_uid
 return item_by_uid(uid)
func swap(a:int,b:int)->bool:
 if a<0 or b<0 or a>=slots.size() or b>=slots.size() or a==b:return false
 var item:Dictionary=slots[a];slots[a]=slots[b];slots[b]=item
 return true
func sort_items()->void:
 var list:Array[Dictionary]=[]
 for item in slots:
  if not item.is_empty():list.append(item)
 var rank:Dictionary={"tool":0,"placeable":1,"food":2,"ward":3,"material":4}
 list.sort_custom(func(a,b):
  var ca:int=int(rank.get(Data.info(a.id).category,5))
  var cb:int=int(rank.get(Data.info(b.id).category,5))
  if ca!=cb:return ca<cb
  if a.id!=b.id:return Data.label(a.id)<Data.label(b.id)
  return int(a.uid)<int(b.uid))
 slots.clear()
 for item in list:slots.append(item)
 while slots.size()<SLOT_COUNT:slots.append({})
func usable(uid:int)->bool:
 var item:Dictionary=item_by_uid(uid)
 return not item.is_empty() and int(item.get("durability",1))>0
func damage(uid:int,amount:int=1)->bool:
 var i:int=index_of_uid(uid)
 if i<0 or not slots[i].has("durability") or not usable(uid):return false
 slots[i].durability=maxi(0,int(slots[i].durability)-maxi(0,amount))
 return true
func repair(uid:int,cost:Dictionary)->bool:
 var item:Dictionary=item_by_uid(uid)
 if item.is_empty() or not item.has("durability") or not can_pay(cost):return false
 var max_durability:int=int(Data.info(item.id).durability)
 if int(item.durability)>=max_durability:return false
 var trial=clone()
 for id in cost:trial.remove(id,int(cost[id]))
 trial.item_by_uid(uid).durability=max_durability
 slots=trial.slots;next_uid=trial.next_uid
 return true
func best_power()->int:
 var result:int=0
 for item in slots:
  if int(item.get("durability",1))>0:result=maxi(result,int(Data.info(item.id).get("power",0)))
 return result
func validate()->bool:
 if slots.size()!=SLOT_COUNT:return false
 var uids:Dictionary={}
 for item in slots:
  if item.is_empty():continue
  var spec:Dictionary=Data.info(item.id)
  if spec.is_empty() or int(item.qty)<1 or int(item.qty)>int(spec.stack):return false
  if uids.has(item.uid) or int(item.uid)<1:return false
  uids[item.uid]=true
  if spec.has("durability") and (int(item.durability)<0 or int(item.durability)>int(spec.durability)):return false
 return true
