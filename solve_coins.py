import itertools

for perm in itertools.permutations([2, 9, 5, 7, 3]):
    if perm[0] + perm[1] * perm[2]**2 + perm[3]**3 - perm[4] == 399:
        print(perm)
