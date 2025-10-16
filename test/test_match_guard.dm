# 测试守卫条件 - 避免使用 Ok/Err 关键字

enum MyResult:
    Success(int)
    Failure(int)

let r1 = MyResult.Success(15)

match r1:
    MyResult.Success(x) if x > 10:
        print(100)
    MyResult.Success(x):
        print(10)
    MyResult.Failure(code):
        print(code)

let r2 = MyResult.Success(5)

match r2:
    MyResult.Success(x) if x > 10:
        print(100)
    MyResult.Success(x):
        print(10)
    MyResult.Failure(code):
        print(code)

let r3 = MyResult.Failure(404)

match r3:
    MyResult.Success(x) if x > 10:
        print(100)
    MyResult.Success(x):
        print(10)
    MyResult.Failure(code):
        print(code)
