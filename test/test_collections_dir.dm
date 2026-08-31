# dream-test: dir

from collections import OrderedSet, Set

def main():
    let left = Set()
    left.add("a")
    left.add("b")
    left.add("c")
    let right = Set()
    right.add("b")
    right.add("c")
    right.add("d")
    let union = left | right
    let intersection = left & right
    let difference = left - right

    print(union.len())
    print(intersection.contains("b"))
    print(difference.contains("a"))
    print(left.is_subset(union))
    print(left.is_disjoint(Set().add("z")))

    let ordered_left = OrderedSet()
    ordered_left.add("first")
    ordered_left.add("second")
    let ordered_right = OrderedSet()
    ordered_right.add("second")
    ordered_right.add("third")
    let ordered_union = ordered_left | ordered_right
    print(ordered_union.first())

main()
