# Dream 核心功能综合测试
# 包含：字符串、泛型

# ========================================
# 字符串基础功能
# ========================================

let s: str = "Hello"
print(s[0])     # 72 (H)
print(s[1])     # 101 (e)

# 字符串切片
let slice1: str = s[1:4]
print(slice1[0])   # 101 (e)

let slice2: str = s[:2]
print(slice2[0])   # 72 (H)

let slice3: str = s[2:]
print(slice3[0])   # 108 (l)

# 字符串方法
print(s.length())  # 5

# ========================================
# 泛型功能
# ========================================

def identity[T](x: T) -> T:
    return x

print(identity(42))      # 42
print(identity(100))     # 100

def first(items: list[int]) -> int:
    if len(items) > 0:
        return items[0]
    return 0

let nums = [1, 2, 3]
print(first(nums))  # 1

let nums2 = [10, 20, 30]
print(first(nums2))  # 10

print(999)
