from flask import Flask
from flask_wtf import CSRFProtect
import boto3
import botocore.exceptions


app = Flask(__name__)
csrf = CSRFProtect()
csrf.init_app(app)


@app.route("/aws_role")
def get_aws_identity():
    try:
        client = boto3.client("sts")
        identity = client.get_caller_identity()
        arn = identity.get("Arn", "Unknown")
        account = identity.get("Account", "Unknown")
        return f"""
        <h1>AWS Identity</h1>
        <p><strong>ARN:</strong> {arn}</p>
        <p><strong>Account ID:</strong> {account}</p>
        """
    except botocore.exceptions.BotoCoreError as e:
        return f"<h1>Error</h1><p>{str(e)}</p>"


@app.route("/")
def hello():
    return "Hello from Flask in Kubernetes!"
