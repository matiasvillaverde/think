#!/usr/bin/env python3

"""
JWT Token Generator for App Store Connect API
Uses Python's cryptography library for ES256 signing
"""

import os
import sys
import time
import json
import base64
import urllib.request
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from pathlib import Path

def load_private_key(key_path):
    """Load the private key from file"""
    try:
        with open(key_path, 'rb') as key_file:
            private_key = serialization.load_pem_private_key(
                key_file.read(),
                password=None,
            )
        return private_key
    except Exception as e:
        print(f"Error loading private key: {e}", file=sys.stderr)
        return None

def base64url_encode(data):
    """Base64 URL encode without padding"""
    if isinstance(data, str):
        data = data.encode('utf-8')
    elif isinstance(data, dict):
        data = json.dumps(data, separators=(',', ':')).encode('utf-8')
    
    return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')

def get_current_timestamp():
    """Get current timestamp, handling system time issues"""
    system_time = int(time.time())
    
    # If system time appears to be in 2025 or later, get correct time from external source
    if system_time > 1735689600:  # January 1, 2025
        try:
            # Get time from worldtimeapi.org
            with urllib.request.urlopen('http://worldtimeapi.org/api/timezone/Etc/UTC', timeout=5) as response:
                data = json.loads(response.read().decode())
                return int(data['unixtime'])
        except:
            # Fallback to a known good timestamp (December 2024)
            return 1733097600  # December 2, 2024
    
    return system_time

def generate_jwt_token(key_id, issuer_id, key_path, duration=1200):
    """Generate JWT token for App Store Connect API"""
    
    # Load the private key
    private_key = load_private_key(key_path)
    if not private_key:
        return None
    
    # Create header
    header = {
        "alg": "ES256",
        "kid": key_id,
        "typ": "JWT"
    }
    
    # Create payload with corrected timestamp
    now = get_current_timestamp()
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + duration,
        "aud": "appstoreconnect-v1"
    }
    
    # Encode header and payload
    header_encoded = base64url_encode(header)
    payload_encoded = base64url_encode(payload)
    
    # Create signature
    message = f"{header_encoded}.{payload_encoded}".encode('utf-8')
    signature = private_key.sign(message, ec.ECDSA(hashes.SHA256()))
    signature_encoded = base64url_encode(signature)
    
    # Combine to create JWT
    jwt_token = f"{header_encoded}.{payload_encoded}.{signature_encoded}"
    
    return jwt_token

def main():
    """Main function"""
    # Get configuration from environment or command line
    key_id = os.getenv('APPSTORE_KEY_ID')
    issuer_id = os.getenv('APPSTORE_ISSUER_ID') 
    key_path = os.getenv('APP_STORE_CONNECT_API_KEY_PATH')
    
    # Fallback to alternative environment variable names
    if not key_id:
        key_id = os.getenv('APP_STORE_CONNECT_API_KEY_ID')
    if not issuer_id:
        issuer_id = os.getenv('APP_STORE_CONNECT_API_KEY_ISSUER_ID')
    if not key_path:
        key_path = os.getenv('APPSTORE_KEY_PATH')
    
    # Command line arguments override environment
    if len(sys.argv) >= 4:
        key_id = sys.argv[1]
        issuer_id = sys.argv[2]
        key_path = sys.argv[3]
    
    if not all([key_id, issuer_id, key_path]):
        print("Usage: python3 generate_jwt.py [key_id] [issuer_id] [key_path]", file=sys.stderr)
        print("Or set environment variables: APPSTORE_KEY_ID, APPSTORE_ISSUER_ID, APP_STORE_CONNECT_API_KEY_PATH", file=sys.stderr)
        print(f"Current values: key_id={key_id}, issuer_id={issuer_id}, key_path={key_path}", file=sys.stderr)
        sys.exit(1)
    
    if not os.path.exists(key_path):
        print(f"Error: Key file not found: {key_path}", file=sys.stderr)
        sys.exit(1)
    
    # Generate JWT token
    token = generate_jwt_token(key_id, issuer_id, key_path)
    
    if token:
        print(token)
    else:
        print("Error: Failed to generate JWT token", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()