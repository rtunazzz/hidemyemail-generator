import json


def read_file_txt(path: str) -> str:
    f = open(path, 'r')
    content = f.read()
    f.close()

    return content


def read_file_json(path: str) -> dict:
    f = open(path, 'r')
    content = json.load(f)
    f.close()

    return content
