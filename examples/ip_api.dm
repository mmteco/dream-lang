# 使用 ip-api.com 查询当前公网 IP 的地理信息

from http import get
from json import Json, loads

def format_location(document: Json) -> str:
    let status = document.get("status").as_str()
    if status != "success":
        return "ip-api error: " + document.get("message")

    let result = "IP: " + document.get("query")
    result += "\nCountry: " + document.get("country")
    result += "\nRegion: " + document.get("regionName")
    result += "\nCity: " + document.get("city")
    result += "\nISP: " + document.get("isp")
    return result

def main():
    let response = get("http://ip-api.com/json/?fields=status,message,query,country,regionName,city,isp")
    if not response.ok():
        print("request failed: " + response.error)
        return

    let document = loads(response.body)
    if document.is_error():
        print("invalid JSON: " + document.error())
        return
    print(format_location(document))

main()
