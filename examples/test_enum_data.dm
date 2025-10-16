# 测试枚举变体带数据的模式匹配

enum Shape:
    Circle(int)
    Rectangle(int, int)
    Point

let s1 = Shape.Circle(5)
let s2 = Shape.Rectangle(10, 20)
let s3 = Shape.Point

match s1:
    Shape.Circle(r):
        print(r)
    Shape.Rectangle(w, h):
        print(w)
    Shape.Point:
        print(0)

match s2:
    Shape.Circle(r):
        print(r)
    Shape.Rectangle(w, h):
        print(w + h)
    Shape.Point:
        print(0)

match s3:
    Shape.Circle(r):
        print(r)
    Shape.Rectangle(w, h):
        print(w)
    Shape.Point:
        print(999)
