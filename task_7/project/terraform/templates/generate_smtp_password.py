#!/usr/bin/env python3
import hmac, hashlib, base64, json, sys

input_data = json.load(sys.stdin)
secret = input_data["secret"]

signature = hmac.new(
    key=("AWS4" + secret).encode("utf-8"), msg=b"SendRawEmail", digestmod=hashlib.sha256
).digest()

# Prefix with version 2
smtp_password = base64.b64encode(b"\x02" + signature).decode("utf-8")

print(json.dumps({"smtp_password": smtp_password}))
