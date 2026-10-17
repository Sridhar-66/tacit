#!/usr/bin/env python3
import calendar
import os
import sys
import json
import google.auth.transport.requests
import google.oauth2.service_account

def get_token(json_str):
    try:
        # Load the string into a dictionary
        info = json.loads(json_str)
        
        # Initialize credentials
        creds = google.oauth2.service_account.Credentials.from_service_account_info(info)
        scoped_creds = creds.with_scopes(['https://www.googleapis.com/auth/cloud-platform'])
        
        # Refresh to get the access token
        request = google.auth.transport.requests.Request()
        scoped_creds.refresh(request)

        token = scoped_creds.token
        expiry = int(calendar.timegm(scoped_creds.expiry.utctimetuple()))
        
        print(json.dumps({
            "token": token,
            "expiry": expiry
        }))

    except Exception as e:
        sys.stderr.write(f"Error: {str(e)}\n")
        sys.exit(1)

if __name__ == "__main__":
    # The key arrives in the environment, never in argv: /proc/<pid>/cmdline is world readable,
    # so the whole service-account private key used to be there for any local process to read.
    key_json = os.environ.get("SERVICE_KEY_CONTENT", "")
    if not key_json:
        sys.stderr.write("Usage: SERVICE_KEY_CONTENT='<json_string>' token_from_key.py\n")
        sys.exit(1)

    get_token(key_json)
