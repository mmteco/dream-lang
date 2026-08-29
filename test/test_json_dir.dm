# dream-test: dir

from json import Json, loads, dumps, empty_object, put, field, at, as_string, as_number, is_error, error

def main():
    let document = loads("{\"name\":\"Dream\",\"items\":[1,true,null,{\"ok\":false}],\"unicode\":\"\\u4f60\\u597d\"}")
    print(dumps(document))
    print(as_string(field(document, "name")))
    print(as_number(at(field(document, "items"), 0)))

    let generated = put(put(empty_object(), "seed", Json.Null), "answer", Json.Number("42"))
    print(dumps(generated))

    let invalid = loads("[1,]")
    print(is_error(invalid))
    print(error(invalid))
