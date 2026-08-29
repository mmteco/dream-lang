# 使用 ip-api.com 查询当前公网 IP 的地理信息

from http import get
from json import Json, loads, field, as_string, is_error, error

def object_summary(document: Json) -> str:
    let status = as_string(field(document, "status"))
    if status != "success":
        return "ip-api error: " + as_string(field(document, "message"))
    let result = "IP: " + as_string(field(document, "query"))
    result = result + "\nCountry: " + as_string(field(document, "country"))
    result = result + "\nRegion: " + as_string(field(document, "regionName"))
    result = result + "\nCity: " + as_string(field(document, "city"))
    return result + "\nISP: " + as_string(field(document, "isp"))

def main():
    let response = get("http://ip-api.com/json/?fields=status,message,query,country,regionName,city,isp")
    if not response.ok():
        print("request failed: " + response.error)
        return

    let document = loads(response.body)
    if is_error(document):
        print("invalid JSON: " + error(document))
        return
    print(object_summary(document))

main()
