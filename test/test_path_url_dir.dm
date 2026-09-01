# dream-test: dir
# path 与 url 标准库测试

from path import Path
from url import parse, build, quote

def main():
    let p1 = Path("a/./b/../c.txt")
    print(p1.to_string())
    let item_path = Path("/tmp/data") / "item.json"
    print(item_path.to_string())
    print(item_path.name())
    print(item_path.parent().to_string())
    print(item_path.suffix())
    print(item_path.stem())

    # --- Path 静态方法测试 ---
    let norm = Path.normalize("foo/bar/../baz/./qux.txt")
    print(norm)
    let is_abs_true = Path.is_abs("/var/log")
    print(is_abs_true)
    let is_abs_false = Path.is_abs("var/log")
    print(is_abs_false)
    let base = Path.basename("/usr/local/bin/dream")
    print(base)
    let dir = Path.dirname("/usr/local/bin/dream")
    print(dir)
    let extension = Path.ext("document.tar.gz")
    print(extension)
    let main_stem = Path.stem_of("document.tar.gz")
    print(main_stem)
    let joined = Path.join("src", "main.dm")
    print(joined.to_string())

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
