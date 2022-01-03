from dotenv import load_dotenv
from bson import json_util
import pymongo
import os
import json
import time
from bson.objectid import ObjectId

from pymongo import ReturnDocument


# Example Document in MongoDB:
# {
#     "title":"Hello there",
#     "content":"I'm a note",
#     "creationDate":1624018788693,
#     "updatedDate":1624018926553
# }


# TODO: smarter cred management 
load_dotenv()
conn_str = os.getenv('MONGODB_URI')
try:
    client = pymongo.MongoClient(conn_str, serverSelectionTimeoutMS=5000)
    print("Connected to MongoDB")
except Exception:
    print("Unable to connect to MongoDB")
db = client[os.getenv("MONGODB_NAME")]


def lambda_handler(event, context):
    if(event["httpMethod"] == "POST"):
        return create_note(event, context)
    if(event["httpMethod"] == "PATCH"):
        return update_note(event, context)
    if(event["httpMethod"] == "GET"):
        return get_note(event, context)
    if(event["httpMethod"] == "DELETE"):
        return delete_note(event, context)
    else:
        return {
            'statusCode': 400,
            'body': json.dumps('Unrecognized method')
        }


def create_note(event, context):
    note = json.loads(event["body"])

    print("Creating note", note)

    current_time = int(time.time()*1000) # to match JS time 
    note["creationDate"] = current_time
    note["updatedDate"] = current_time

    print(note)

    mongo_collection = db["notes"]
    mongo_collection.insert_one(note)

    print(note)

    return gen_response(note, 200, {})


def get_note(event, context):
    print('Retrieving notes')

    mongo_collection = db["notes"]
    notes = cursor_to_list(mongo_collection.find().limit(15))
    
    print('Retrieved notes:', notes)

    return gen_response(notes, 200, {})


def update_note(event, context):
    _id = event["pathParameters"]["id"]
    print(event)
    print("Updating note with ID:", _id)

    body = json.loads(event["body"])
    current_time = int(time.time()*1000) # to match JS time 
    body["updatedDate"] = current_time

    mongo_collection = db["notes"]
    updated_doc = mongo_collection.find_one_and_update(
        { "_id":  ObjectId(_id) },
        { "$set":  body },
        return_document = ReturnDocument.AFTER
    )
    print(updated_doc)

    print("Updated", _id, "successfully,", updated_doc)
    return gen_response(updated_doc, 200, {})



def delete_note(event, context):
    _id = event["pathParameters"]["id"]
    print("Deleting note with ID:", _id)

    mongo_collection = db["notes"]
    updated_doc = mongo_collection.delete_one(
        { "_id":  ObjectId(_id) }
    )
    print(updated_doc)

    print("Deleted", _id, "successfully,", updated_doc)
    return gen_response({"message": "Delete successful"}, 200, {})


def gen_response(body, code, headers):
    return {
        "statusCode": code,
        "headers": headers,
        "body": json_util.dumps(body),
        "isBase64Encoded": False
    }

def cursor_to_list(cursor):
    result = []
    for doc in cursor:
        result.append(doc)
    return result 