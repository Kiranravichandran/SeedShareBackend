from flask import Flask, jsonify, request
import json
from service.SeedshareModule import SeedshareService
with open("constants/app-response.json") as f:
    output = json.load(f)

app = Flask(__name__)

@app.route("/")
def healthCheck():
    output["status_code"] = 200
    output["response"] = "Hello from Seedshare"
    return jsonify(output)

@app.route("/createFarmer", methods=["POST"])
def create_farmer():
    try:
        request_data = request.data
        request_data_str = request_data.decode("utf-8")
        json_data = request.get_json()
        result = SeedshareService.createFarmer(json_data["name"],json_data["emailId"], json_data["phoneNumber"], json_data["aadharNumber"])
        output["status_code"] = 200
        output["response"] = result
        return jsonify(output)
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})

if __name__ == "__main__":
    app.run(port=8080,debug=True)