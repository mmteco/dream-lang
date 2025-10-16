def quicksort(arr: list[T]) -> list[T]:
    if len(arr) <= 1:
        return arr
    
    let pivot = arr[0]
    let less = [x for x in arr[1:] if x < pivot]
    let greater = [x for x in arr[1:] if x >= pivot]
    
    return quicksort(less) + [pivot] + quicksort(greater)


def main():
    let nums = [3, 7, 1, 9, 2, 5]
    let sorted = quicksort(nums)

    let i = 0
    while i < len(sorted):
        print(sorted[i])
        i = i + 1

main()
