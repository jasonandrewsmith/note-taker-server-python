#!/usr/bin/bash

python3 -m venv test-venv
source test-venv/bin/activate

rm -rf build 
mkdir -p build/layers/python 

pip3 install -r requirements.txt --target build/
cd build/
zip -r ../build/notes.zip *

cd ../src
zip -r ../build/notes.zip *
cd ..
zip -r build/notes.zip .env


# aws lambda publish-layer-version \
#     --layer-name notes_deps \
#     --zip-file fileb:///home/jason/_DEV/note-taker/note-taker-server-python/build/dep_layer.zip
# aws lambda update-function-configuration \
#     --function-name notes \
#     --layers arn:aws:lambda:us-east-1:837712377044:layer:notes_dep_layer:1
aws lambda update-function-code \
    --function-name notes \
    --zip-file fileb:///home/jason/_DEV/note-taker/note-taker-server-python/build/notes.zip
