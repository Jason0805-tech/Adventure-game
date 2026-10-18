def weapon_craft(b,r,g,power, bag_weapon):
    print ("Here are some weapons you can make and their materials needed and their power you can gain.")
    print("amazing stone sword                 large stone sword + 1 rock       5\nlarge stone sword                   3 4 3       4\nshort stone knife                   2 2 1       2\nstone axe                           2 3 2       3\nwooden knife                        4 0 2       3\nwooden sword                        5 1 2       4")
    while True:
        pick = input("Which one do you want to make.")
        if(pick == "amazing stone sword"):
            if('large stone sword' in bag_weapon and r >= 1):
                bag_weapon.remove('large stone sword')
                bag_weapon.append('amazing stone sword')
                power += 1
                b -= 3
                r -= 5
                g -= 3
                break
        elif(pick == "large stone sword" and b >= 3 and r >= 4 and g >= 3):
            bag_weapon.append('large stone sword' )
            power += 4
            b -= 3
            r -= 4
            g -= 3
            break
        elif(pick == 'short stone knife' and b >= 2 and r >= 2 and g >= 1):
            bag_weapon.append('short stone knife')
            power += 2
            b -= 2
            r -= 2
            g -= 1
            break
        elif(pick == "stone axe" and b >= 2 and r >= 3 and g >= 2):
            bag_weapon.append('stone axe')
            power += 3
            b -= 2
            r -= 3
            g -= 2
            break
        elif(pick == "wooden knife" and b >= 4 and r >= 0 and g >= 2):
            bag_weapon.append('wooden knife')
            power += 3
            b -= 4
            r -= 0
            g -= 2
            break
        elif(pick == "wooden sword" and b >= 5 and r >= 1 and g >= 2):
            bag_weapon.append('wooden sword')
            power += 4
            b -= 5
            r -= 1
            g -= 2
            break
        else:
            print("You don't have enough materials, or the weapon name is invalid")
    return b, r, g, power, bag_weapon

def collection(b,r,g):
    while True:
        new_b = int(input("How many branches do you want to collect?"))
        new_r = int(input("How many rocks?"))
        new_g = int(input("How many grass ropes do you want to make?"))
        if(new_b < 0 or new_r < 0 or new_g < 0):
            print("You can't collect a negative number of materials!")
        elif(b + r + g + new_b + new_r + new_g > 10):
            print("You can't carry all of them! You can only carry 10 items.")
        else:
            b += new_b
            r += new_r
            g += new_g
            break
    return b, r, g

def food_check(hungry):
    if(hungry <= 60):
        return ("You need to eat some food")
    elif(hungry <= 40):
        return ("You are hungry")
    elif(hungry <= 20):
        return ("You feel so uncomfortable")
    else:
        return ("You are straved")
    
    
print ("You are in a dark forest. You want to make something to protect yourself.\n")
print ("You need to collect some materials, but you can only carry 10 items.\n")
print ("There are a lot of branches, small rocks, and grass which can make ropes to help you tie things together.")

b = 0
r = 0
g = 0
hungry = 100
bag = []
bag_weapon = []
power = 0
b,r,g = collection(b,r,g)
b, r, g, power, bag_weapon = weapon_craft(b,r,g,power,bag_weapon)
night = 1
power_num = 3
while night <= 3:
    while True:
        print("Night is coming. Make sure you have already protected yourself.")
        hungry -= 30
        choice = input("You can choose to explore the forest, rest or look for food: ")
        if(choice == "explore"):
            power += 2
            hungry -= 20
            bag.append("magic stone")
            print("You find a magic stone.")
            break
        elif(choice == "rest"):
            print("You feel better.")
            power += 1
            hungry -= 5
            break
        elif(choice == "look for food"):
            print("You find some berries.")
            power += 1
            hungry += 30
            bag.append("medicine")
            print("You find some medicine.")
            break
        else:
            print("Invalid choice, choose again.")
    print("You hear something moving in the bushes...")
    print(food_check)
    if(power < power_num):
        if("magic stone" in bag):
            print("You are safed by the magic stone.")
            bag.remove("magic stone")
        elif("medicine" in bag):
            print("You treat yourself by the medicine.")
            bag.remove("medicine")
        else:
            print("You are killed by something in the dark... GAME OVER")
            break
    else:
        print("You survived NIGHT",night)
        if(night < 3):
            print("You can collect materials right now.")
            b,r,g = collection(b,r,g)
            b, r, g, power, bag_weapon = weapon_craft(b,r,g,power,bag_weapon) 
    night += 1
    power_num += 3
else:
    print("You survived all three nights. You successfully escaped the forest. YOU WIN!")