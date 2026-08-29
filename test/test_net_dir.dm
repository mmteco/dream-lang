# dream-test: dir

from net import connect

def main():
    let connection = connect("", 0)
    print(connection.is_open())
    print(connection.write("request"))
    print(connection.read())
    print(connection.close())
