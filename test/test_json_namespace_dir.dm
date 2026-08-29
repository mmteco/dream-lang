# dream-test: dir

import json

def main():
    let value = json.loads('''{"name":"Dream"}''')
    print(json.dumps(value))
