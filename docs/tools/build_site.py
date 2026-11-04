import json
import os
import re
import sys

DOCS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUIDE = os.path.join(DOCS, 'guide')
TEMPLATE = os.path.join(DOCS, 'tools', 'site_template.html')
OUT = os.path.join(DOCS, 'site', 'index.html')
VERSION = '1.3'

HEAD = ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
        '<style>:root{color-scheme:light}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>'
        '</head><body>')


def pages():
    result = []
    for name in sorted(os.listdir(GUIDE)):
        if not name.endswith('.md'):
            continue
        text = open(os.path.join(GUIDE, name), encoding='utf-8').read()
        match = re.search(r'^# (.+)$', text, re.M)
        title = match.group(1).strip() if match else name
        slug = re.sub(r'^\d+-', '', name[:-3])
        result.append({'file': name, 'slug': slug, 'title': title, 'markdown': text})
    return result


def build(fragment_only=False):
    data = json.dumps({'version': VERSION, 'pages': pages()}, ensure_ascii=False).replace('</', '<\\/')
    body = open(TEMPLATE, encoding='utf-8').read().replace('__DOCS__', data)
    return body if fragment_only else HEAD + body + '</body></html>'


if __name__ == '__main__':
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write(build())
    if len(sys.argv) > 1:
        open(sys.argv[1], 'w', encoding='utf-8').write(build(True))
    print(OUT)
