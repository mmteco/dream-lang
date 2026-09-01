# 使用 ip-api.com 查询当前公网 IP 的地理信息

from http import get
from json import Json, loads

def print_info(document: Json):
    let status = document.get("status")
    if str(status) != "success":
        print("ip-api error: " + document.get("message"))
        return

    print("IP: " + document.get("query"))
    print("Country: " + document.get("country"))
    print("Region: " + document.get("regionName"))
    print("City: " + document.get("city"))
    print("ISP: " + document.get("isp"))

def main():
    let response = get("http://ip-api.com/json/?fields=status,message,query,country,regionName,city,isp")
    if not response.ok():
        print("request failed: " + response.error)
        return

    let document = loads(response.body)
    if document.is_error():
        print("invalid JSON: " + document.error())
        return
    print_info(document)

main()
