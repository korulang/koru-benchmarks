#!/usr/bin/env python3
# Deterministic generator for data/doc.json (seed 41). Constraints that keep
# the document inside std/parser cut-1's grammar and stack budget:
#   - minified (single line, no inter-token whitespace)
#   - no backslash escapes inside strings (v1 simplicity; the grammar's
#     string terminal handles them, baselines don't care)
#   - arrays <= 16 elements, objects <= 8 keys, nesting <= 4: the Koru
#     recognizer's list rules are RIGHT-RECURSIVE, so recursion depth tracks
#     list length — bounded here by design, and documented in README.md.
import json, random
random.seed(41)
def val(d):
    r = random.random()
    if d <= 0: return random.choice([random.randint(-9999,9999), round(random.uniform(-100,100),3), True, False, None, 'word'+str(random.randint(0,999))])
    if r < 0.22: return {'k%d'%i: val(d-1) for i in range(random.randint(1,8))}
    if r < 0.42: return [val(d-1) for i in range(random.randint(1,16))]
    if r < 0.62: return random.randint(-10**9,10**9)
    if r < 0.8: return round(random.uniform(-1e6,1e6),6)
    if r < 0.92: return 'the quick brown fox %d jumps' % random.randint(0,9999)
    return random.choice([True, False, None])
doc = {'items': [val(4) for _ in range(48)], 'meta': {'name': 'bench doc', 'version': 3}}
s = json.dumps(doc, separators=(',',':'))
open(__file__.rsplit('/',1)[0] + '/data/doc.json','w').write(s)
print('bytes:', len(s))
