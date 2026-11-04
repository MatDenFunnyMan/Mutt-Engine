import json
import os

DOCS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(DOCS, 'tools', 'lua-api.json')
OUT = os.path.join(DOCS, 'guide', '15-lua-api.md')

INTRO = """# Lua API

Every Lua function of Mutt Engine, by category.

- **NEW** = added by Mutt Engine. **CHANGED** = works differently than in Psych Engine.
- **DEPRECATED** = still works, but use the function written next to it. With `luaDebugMode = true` the game shows a warning.
- **STATE** = only in custom state scripts (see [Scripting](09-scripting.md#custom-states)).
- `?` before a value = optional. `{...}` = an options table: write only the options you need, by name (`{alpha = 0.5}`).

This page is made from the same list used by the **DogO-01** VS Code extension.
"""


def cell(text):
    return text.replace('|', '\\|').replace('\n', ' ').strip()


def build():
    data = json.load(open(DATA, encoding='utf-8'))
    rows = data['rows']
    lines = [INTRO]
    for category in data['order']:
        group = [r for r in rows if r['c'] == category]
        if not group:
            continue
        lines.append(f'## {category}\n')
        lines.append('| Function | What it does |')
        lines.append('|---|---|')
        for r in group:
            tags = []
            if r['st'] == 'new':
                tags.append('**NEW**')
            if r['st'] == 'changed':
                tags.append('**CHANGED**')
            if r['s'] == 'state':
                tags.append('**STATE**')
            if r['dep']:
                tags.append('**DEPRECATED**' + (f' - use `{cell(r["to"])}`' if r['to'] else ''))
            name = f'`{cell(r["n"])}`' if r['p'] == 'callbacks' else f'`{cell(r["n"])}({cell(r["p"])})`'
            desc = cell(r['d'])
            if r['note']:
                desc += ' ' + cell(r['note'])
            if tags:
                desc = ' · '.join(tags) + '<br>' + desc
            lines.append(f'| {name} | {desc} |')
        lines.append('')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines))
    return len(rows)


if __name__ == '__main__':
    print(build(), OUT)
