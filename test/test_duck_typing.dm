# Go 风格隐式接口实现示例 - 结构体内部方法

# 定义接口
interface Speaker:
    def speak(self) -> string

# 定义结构体,在内部定义方法
struct Dog:
    name: string

    def speak(self) -> string:
        return "Woof!"

struct Cat:
    name: string

    def speak(self) -> string:
        return "Meow!"

# 函数接受接口类型
def make_speak(animal: Speaker) -> string:
    return animal.speak()

# 创建实例
let dog = Dog{name: "Buddy"}
let cat = Cat{name: "Whiskers"}

# 隐式满足接口
let dog_sound = make_speak(dog)
let cat_sound = make_speak(cat)

print(dog_sound)
print(cat_sound)
