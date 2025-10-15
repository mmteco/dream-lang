# Test multiple top-level loops (the original bug that was fixed)

# First loop: while
let i = 0
while i < 5:
    print(i)
    i = i + 1

# Second loop: for
for j in [10, 20, 30]:
    print(j)
