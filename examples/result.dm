# Result 类型示例
# Result 是内置类型，无需定义
# Ok, Err 全局可用，无需前缀

# 创建 Result 值（无需前缀）
let success_result = Ok(42)
let failure_result = Err(404)

# 使用 match 处理 Result（无需前缀）
match success_result:
    Ok(value):
        print(value)
    Err(error):
        print(error)

match failure_result:
    Ok(value):
        print(value)
    Err(error):
        print(error)

# 使用守卫条件的 Result 匹配
let res1 = Ok(200)
let res2 = Err(500)

match res1:
    Ok(code) if code == 200:
        print(1)
    Ok(code):
        print(2)
    Err(code):
        print(3)

match res2:
    Ok(code) if code == 200:
        print(1)
    Ok(code):
        print(2)
    Err(code) if code >= 500:
        print(3)
    Err(code):
        print(4)
