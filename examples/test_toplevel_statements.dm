# Test various top-level statements with Python-style comments

# Simple let statement
let x = 10
print(x)  # Should print 10

# While loop at top level
let i = 0
while i < 3:
    print(i)  # Loop iteration
    i = i + 1

# For loop at top level
for j in [20, 30, 40]:
    print(j)  # Print each element

# If statement at top level
if x > 5:
    print(100)

# If-else statement
if x < 5:
    print(200)
else:
    print(300)  # Should take else branch

# Multiple functions
def foo():
    print(1000)

def bar():
    print(2000)

foo()  # Call foo
bar()  # Call bar

# Final print
print(9999)
