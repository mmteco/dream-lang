def test_dict_str_basic():
    let d = {"name": 100, "age": 25, "city": 300}
    print(d["name"])
    print(d["age"])
    print(d["city"])

def test_dict_str_assignment():
    let d = {"count": 0}
    d["count"] = 10
    d["count"] = 20
    print(d["count"])

def test_dict_int_still_works():
    let d = {1: 10, 2: 20, 3: 30}
    print(d[1])
    print(d[2])
    print(d[3])

test_dict_str_basic()
test_dict_str_assignment()
test_dict_int_still_works()
