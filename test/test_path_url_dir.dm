# dream-test: dir
# path 与 url 标准库测试

from path import join, normalize, basename, dirname, ext, stem
from url import parse, build, quote

def main():
    print(normalize("a/./b/../c.txt"))
    print(join("/tmp/data", "item.json"))
    print(basename("/tmp/data/item.json"))
    print(dirname("/tmp/data/item.json"))
    print(ext("/tmp/data/item.json"))
    print(stem("/tmp/data/item.json"))

    let address = parse("https://example.com:8443/a?q=1#top")
    print(address.scheme)
    print(address.host)
    print(address.port)
    print(address.path)
    print(address.query)
    print(address.fragment)
    print(build(address))
    print(quote("a b+c"))

main()
