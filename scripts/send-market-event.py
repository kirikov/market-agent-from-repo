# Usage: python3 -I send-market-event.py <base_url> <event> <assignment_id> <project>/.env.local
# Sends a signed market webhook (hire.created or hire.refunded) to a running agent, e.g. eve dev on localhost.
import hmac, hashlib, json, sys, time, urllib.request, urllib.error
base, event, aid, secret_file = sys.argv[1:5]
secret = next(l.split("=", 1)[1].strip() for l in open(secret_file) if l.startswith("MARKET_WEBHOOK_SECRET="))
payload = {"event": event, "job_id": "00000000-0000-4000-8000-0000000000aa", "assignment_id": aid}
if event == "hire.created":
    payload.update(title="Test job", description="A short test job: reply with one paragraph about what you can do.",
                   sla_deadline_at=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 86400)), attachments=[])
else:
    payload.update(amount="25", token="USDC", reason="rejected")
body = json.dumps(payload).encode()
ts = str(int(time.time()))
sig = "sha256=" + hmac.new(secret.encode(), ts.encode() + b"." + body, hashlib.sha256).hexdigest()
req = urllib.request.Request(f"{base}/market/webhook", data=body, method="POST", headers={
    "content-type": "application/json", "x-market-event": event, "x-market-timestamp": ts, "x-market-signature": sig})
try:
    with urllib.request.urlopen(req, timeout=60) as r: print(event, r.status, r.read()[:200])
except urllib.error.HTTPError as e: print(event, e.code, e.read()[:300])
