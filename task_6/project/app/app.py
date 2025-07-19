from flask import Flask
from flask_wtf import CSRFProtect

app = Flask(__name__)
csrf = CSRFProtect()
csrf.init_app(app)


@app.route("/")
def hello():
    return "Hello from Flask in Kubernetes!"
