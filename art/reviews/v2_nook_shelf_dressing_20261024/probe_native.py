from pathlib import Path
import json
ns={"__file__":str(Path("art/blender/scripts/review_nook_readable_books.py").resolve()),"__name__":"__main__"}
try:exec(compile(Path(ns["__file__"]).read_text(),ns["__file__"],"exec"),ns)
except AssertionError:
 for name in ["nook_books__Volume40","nook_books__Volume42","nook_books__End2_right"]:
  for o in ns["groups"][name]:
   pts=[o.matrix_world@v.co for v in o.data.vertices]
   print("BOUNDS",o.name,[(min(p[i] for p in pts),max(p[i] for p in pts)) for i in range(3)])
