# Option 类型示例
# Option 是内置类型，无需定义
# Some, None 全局可用，无需前缀

# 创建 Option 值（无需前缀）
let some_value = Some(42)
let no_value = None

# 使用 match 处理 Option（无需前缀）
match some_value:
    Some(x):
        print(x)
    None:
        print(-1)

match no_value:
    Some(x):
        print(x)
    None:
        print(-1)

# 使用守卫条件的 Option 匹配
let opt1 = Some(15)
let opt2 = Some(5)

match opt1:
    Some(x) if x > 10:
        print(100)
    Some(x):
        print(10)
    None:
        print(0)

match opt2:
    Some(x) if x > 10:
        print(100)
    Some(x):
        print(10)
    None:
        print(0)
