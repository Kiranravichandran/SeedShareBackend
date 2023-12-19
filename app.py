from flask import Flask, jsonify
import json
with open("constants/app-response.json") as f:
    output = json.load(f)

app = Flask(__name__)

@app.route("/")
def healthCheck():
    output["status_code"] = 200
    output["response"] = "Hello from Seedshare"
    return jsonify(output)

if __name__ == "__main__":
    app.run(port=8080,debug=True)