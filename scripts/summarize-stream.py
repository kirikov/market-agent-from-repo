# Usage: python3 -I summarize-stream.py < stream.ndjson
# Summarizes an eve session stream: skills and tool calls, errors, truncation, and the final reply.
import json, os, sys
last = None
for line in sys.stdin:
    try:
        e = json.loads(line)
    except Exception:
        continue
    t, d = e.get("type"), e.get("data", {})
    if t == "actions.requested":
        for a in d.get("actions", []):
            inp = json.dumps(a.get("input", {}), ensure_ascii=False)
            name = a.get("toolName") or f"{a.get('kind')}:{a.get('name')}"
            print(f"  call  {name} {inp[:140]}")
    elif t == "action.result":
        r = d.get("result", {})
        body = json.dumps(r.get("output", r), ensure_ascii=False)
        if "error" in body[:400].lower() or r.get("isError"):
            print(f"  ERROR {r.get('toolName') or r.get('name')}: {body[:300]}")
    elif t == "message.completed":
        last = d
        if d.get("finishReason") == "length":
            print("  TRUNCATED: the model hit its output limit (check maxOutputTokens in agent.ts)")
        elif d.get("finishReason") == "tool-calls" and d.get("message"):
            print(f"  says  {d['message'][:200]}")
    elif t in ("turn.failed", "step.failed"):
        print(f"  {t.upper()}: {json.dumps(d, ensure_ascii=False)[:500]}")
    elif t == "turn.completed":
        print("  turn completed")
        break
if last and last.get("finishReason") != "tool-calls":
    msg = last.get("message") or ""
    print(f"\n=== final reply: {len(msg)} chars, finish={last.get('finishReason')} ===")
    print(msg if len(msg) <= 3000 else msg[:2000] + "\n[...]\n" + msg[-800:])
else:
    print("\n(no final reply within the time limit)")
