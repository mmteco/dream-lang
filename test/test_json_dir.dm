# dream-test: dir

from json import Json, loads, dumps, empty_object

def main():
    let document = loads("{\"name\":\"Dream\",\"items\":[1,true,null,{\"ok\":false}],\"unicode\":\"\\u4f60\\u597d\"}")
    print(dumps(document))
    print(dumps(Json.String("quote: \" and line\n")))
    print(document.get("name").as_str())
    print(document.get("items").at(0).as_num())
    print("name=" + document.get("name"))

    let generated = empty_object().put("seed", Json.Null).put("answer", Json.Number("42"))
    generated = generated.put("seed", Json.Bool(true))
    print(generated.dump())

    let invalid = loads("[1,]")
    print(invalid.is_error())
    print(invalid.error())
