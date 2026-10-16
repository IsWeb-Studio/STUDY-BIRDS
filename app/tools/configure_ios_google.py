"""Configure Google's iOS OAuth client and matching redirect URL scheme."""
import argparse
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--client-id', required=True)
args = parser.parse_args()
client = args.client_id.strip()
if not re.fullmatch(r'\d+-[a-z0-9]+\.apps\.googleusercontent\.com', client):
    parser.error('Expected an iOS OAuth client ID ending in .apps.googleusercontent.com')
web = '495236497658-q78f4513t3rj6neonktm49h2h3tlickf.apps.googleusercontent.com'
if client == web:
    parser.error('This is the web client ID. Supply the iOS client for com.studybirds.studyBirds.')
reversed_id = '.'.join(reversed(client.split('.')))
target = Path(__file__).resolve().parents[1] / 'ios/Flutter/GoogleSignIn.xcconfig'
target.write_text(f'// iOS OAuth client for com.studybirds.studyBirds\nGOOGLE_IOS_CLIENT_ID = {client}\nGOOGLE_IOS_REVERSED_CLIENT_ID = {reversed_id}\n', encoding='utf-8')
print('Configured iOS Google client and redirect scheme. Rebuild the iOS app.')
