from struct_import_fixture import ImportedPoint

def make_point(x: int, y: int) -> ImportedPoint:
    return ImportedPoint{x: x, y: y}

def main():
    let point: ImportedPoint = make_point(2, 5)
    print(point.x + point.y)
