"""A small text survival game. Run with Python 3."""

# Recipe values: branches, rocks, grass ropes, power gained.
RECIPES = {
    "large stone sword": (3, 4, 3, 4),
    "short stone knife": (2, 2, 1, 2),
    "stone axe": (2, 3, 2, 3),
    "wooden knife": (4, 0, 2, 3),
    "wooden sword": (5, 1, 2, 4),
}


def read_amount(prompt):
    """Keep asking until the player enters a non-negative whole number."""
    while True:
        try:
            amount = int(input(prompt))
        except ValueError:
            print("Please enter a whole number, such as 0, 1 or 2.")
            continue
        if amount < 0:
            print("You can't collect a negative number of materials!")
        else:
            return amount


def collection(b, r, g):
    while True:
        print(f"Materials: {b} branches, {r} rocks, {g} grass ropes.")
        print(f"Space remaining: {10 - b - r - g}. Enter 0 to collect none.")
        new_b = read_amount("How many branches do you want to collect? ")
        new_r = read_amount("How many rocks? ")
        new_g = read_amount("How many grass ropes do you want to make? ")
        if b + r + g + new_b + new_r + new_g > 10:
            print("You can only carry 10 materials. Please choose again.")
        else:
            return b + new_b, r + new_r, g + new_g


def weapon_craft(b, r, g, power, bag_weapon):
    print("\nWeapon recipes (branches / rocks / grass ropes -> power):")
    for name, (need_b, need_r, need_g, gain) in RECIPES.items():
        print(f"  {name}: {need_b} / {need_r} / {need_g} -> +{gain}")
    print("  amazing stone sword: large stone sword + 1 rock -> upgrade from 4 to 5 power")
    while True:
        print(f"Materials available: {b} branches, {r} rocks, {g} grass ropes.")
        pick = input("Type a weapon name, or 'cancel' to return: ").strip().lower()
        if pick == "cancel":
            return b, r, g, power, bag_weapon
        if pick == "amazing stone sword":
            if "large stone sword" not in bag_weapon or r < 1:
                print("You need a large stone sword and 1 rock for this upgrade.")
                continue
            bag_weapon.remove("large stone sword")
            bag_weapon.append(pick)
            r -= 1
            power += 1
        elif pick in RECIPES:
            need_b, need_r, need_g, gain = RECIPES[pick]
            if b < need_b or r < need_r or g < need_g:
                print("Not enough materials. Type 'cancel' to return and collect more.")
                continue
            b -= need_b
            r -= need_r
            g -= need_g
            power += gain
            bag_weapon.append(pick)
        else:
            print("Unknown weapon name. Choose a listed weapon or type 'cancel'.")
            continue
        print(f"You made {pick}! Your power is now {power}.")
        return b, r, g, power, bag_weapon


def food_check(hungry):
    # A higher value means the player is better fed.
    if hungry <= 0:
        return "You are starving!"
    if hungry <= 20:
        return "You are very hungry and feel uncomfortable."
    if hungry <= 40:
        return "You are hungry."
    if hungry <= 60:
        return "You should eat some food soon."
    return "You feel well fed."


def show_bag(b, r, g, power, hungry, bag, bag_weapon):
    print(f"\nMaterials ({b + r + g}/10): {b} branches, {r} rocks, {g} grass ropes")
    print("Weapons:", ", ".join(bag_weapon) or "none")
    print("Special items:", ", ".join(bag) or "none")
    print(f"Power: {power} | Fullness: {hungry}/100")


def preparation(b, r, g, power, hungry, bag, bag_weapon):
    while True:
        choice = input("\nPrepare: collect / craft / bag / continue: ").strip().lower()
        if choice == "collect":
            b, r, g = collection(b, r, g)
        elif choice == "craft":
            b, r, g, power, bag_weapon = weapon_craft(b, r, g, power, bag_weapon)
        elif choice == "bag":
            show_bag(b, r, g, power, hungry, bag, bag_weapon)
        elif choice == "continue":
            return b, r, g, power, bag_weapon
        else:
            print("Please enter collect, craft, bag or continue.")


def main():
    print("You are in a dark forest. Survive three nights to escape!")
    print("Collect branches, rocks and grass ropes to craft weapons.")
    print("You can carry 10 materials. Weapons and special items use separate storage.")
    print("Weapon power adds up. Fullness gives advice but does not cause damage yet.")
    b = r = g = power = 0
    hungry = 100
    bag = []
    bag_weapon = []

    for night in range(1, 4):
        power_num = night * 3
        print(f"\n--- Before night {night} | Power needed: {power_num} ---")
        b, r, g, power, bag_weapon = preparation(
            b, r, g, power, hungry, bag, bag_weapon
        )
        print("Night is coming. Make sure you have protected yourself.")
        while True:
            choice = input("Choose: explore / rest / look for food: ").strip().lower()
            if choice in ("explore", "rest", "look for food"):
                break
            print("Invalid choice. Enter explore, rest or look for food.")

        # Charge the night's cost only after receiving a valid action.
        hungry -= 30
        if choice == "explore":
            power += 2
            hungry -= 20
            bag.append("magic stone")
            print("You find a magic stone.")
        elif choice == "rest":
            power += 1
            hungry -= 5
            print("You rest and feel better.")
        else:
            power += 1
            hungry += 30
            bag.append("medicine")
            print("You find some berries and medicine.")
        hungry = max(0, min(100, hungry))
        print(f"Fullness: {hungry}/100. {food_check(hungry)}")
        print(f"You hear movement in the bushes... Your power: {power}; needed: {power_num}.")

        if power < power_num:
            if "magic stone" in bag:
                bag.remove("magic stone")
                print("The magic stone saves you and is used up.")
            elif "medicine" in bag:
                bag.remove("medicine")
                print("You survive your injuries by using medicine.")
            else:
                print("You are killed by something in the dark... GAME OVER")
                return
        print(f"You survived NIGHT {night}!")
    print("You survived all three nights and escaped the forest. YOU WIN!")


if __name__ == "__main__":
    try:
        main()
    except (EOFError, KeyboardInterrupt):
        print("\nGame closed. Thanks for playing!")
