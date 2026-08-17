def main():
    let numbers = [1, 2, 3, 4]
    let doubled = [value * 2 for value in numbers]
    let filtered = [value for value in numbers if value > 2]
    print(len(doubled))
    print(doubled[0])
    print(doubled[3])
    print(len(filtered))
    print(filtered[0])
    print(filtered[1])
