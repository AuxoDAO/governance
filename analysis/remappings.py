'''
Simple script to copy remappings file to slither config file
'''
import json

# Get remappings from the remappings.txt file, removing any empty lines
with open('./remappings.txt', 'r') as f:
    remappings: str = f.read()
items: list[str] = [i for i in remappings.split('\n') if i != '']

# Grab the remappings saved slither config
with open('./slither.config.json', 'r') as j:
    data = json.load(j)
existing_slither_remappings = data.get('solc_remaps')

# update the slither config to reflect remappings.txt
if existing_slither_remappings and items:
    data['solc_remaps'] = items
    with open('./slither.config.json', 'w') as _of:
        _of.write(json.dumps(data, indent=4))
        print('Mappings written to slither.config.json:', data['solc_remaps'])
