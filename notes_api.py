from flask import Flask, request
from flask_restful import Resource, Api, reqparse
from dotenv import load_dotenv
import pymongo
import os

app = Flask(__name__)
api = Api(app)

load_dotenv()

# notes = { "123": {"title": "yeet", "content": "yah"}}

conn_str = os.getenv('MONGODB_URI')

try:
    client = pymongo.MongoClient(conn_str, serverSelectionTimeoutMS=5000)
    print("Connected to MongoDB")
except Exception:
    print("Unable to connect to MongoDB")

db = client[os.getenv("MONGODB_NAME")]
mongo_collection = db["notes"]

parser = reqparse.RequestParser()
parser.add_argument('username', type=str)
parser.add_argument('password', type=str)

class Note(Resource):
    def post(self):
        request.get_json(force=True)
    
    def get(self, todo_id):
        return {todo_id: notes[todo_id]}

    def put(self, todo_id):
        return {todo_id: notes[todo_id]}

   


api.add_resource(Note, os.getenv("API_BASE_URL")+"/note/<string:todo_id>")


if __name__ == '__main__':
    app.run(debug=True)