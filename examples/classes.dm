# 接口定义
interface Animal:
    name: str
    def speak(self) -> str

# 类实现
class Dog implements Animal:
    name: str
    breed: str

    def __init__(self, name: str, breed: str):
        self.name = name
        self.breed = breed

    def speak(self) -> str:
        return "Woof!"

class Cat implements Animal:
    name: str

    def __init__(self, name: str):
        self.name = name

    def speak(self) -> str:
        return "Meow!"

# 使用多态
def make_animals_speak(animals: list[Animal]):
    for animal in animals:
        print(animal.speak())

let pets: list[Animal] = [
    Dog("Buddy", "Golden Retriever"),
    Cat("Whiskers")
]

make_animals_speak(pets)
