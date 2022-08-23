import json

data = {
    "type": "Everscale Domain",
    "name": "None",
    "description": "None",
    "preview": {
        "source": "None",
        "mimetype": "image/png"
    },
    "files": [],
    "external_url": "None",
    "target": "None",
    "init_time": None,
    "expire_time": None,
}
template = json.dumps(data, separators=(',', ':')) \
    .replace('{', '{{').replace('}', '}}') \
    .replace('"', '\\"') \
    .replace('None', '{}') \
    .replace('null', '{}')
print('"' + template + '",')
