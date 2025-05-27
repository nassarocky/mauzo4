
from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
import random
import string
import requests
import uuid
import os
from datetime import datetime, timedelta 

app = Flask(__name__)
CORS(app)

@app.after_request
def add_csp_header(response):
    csp_policy = (
        "default-src 'self' http://lightnet.lightnetwork.pro:5000; "  # Add domain here
        "connect-src 'self' http://lightnet.lightnetwork.pro:5000; "
        "script-src 'self' 'unsafe-inline'; "
        "style-src 'self' 'unsafe-inline'"
    )
    response.headers["Content-Security-Policy"] = csp_policy
    return response

# MySQL connection details
db_config = {
    'user': 'radius',
    'password': 'ROCKY221122',
    'host': 'localhost',
    'database': 'radius'
}



#   AZAMPAY START


AZAM_CLIENT_ID = 'c7b6bda0-9a3f-47fb-b365-1110dfc37089'
AZAM_CLIENT_SECRET = 'EsOPLBAfwnLGCQUHOqjMaTqXm/nPv4A8o0WndaEZ4yJ9oJYLkVgPHeQvKPKA2exyvWEAnFL0fBipGq1Qbll6ePoPNfYdsIxYGd5g9UhyK1l8ytGnS3XQj6GUjCfo0J35sb0wgdFwpruktQ2a9SXdKMkuaCtjHPesNHCqPtoy9fUZmabAh7Igi5ZSA2UlTP8WQjaXmaoYEn8aJ1AQxCIEcaIo+DijH7w4hsCmoVWQTHnfpuYDrz3ndpE0eAPRfP381UBxNPuuedtckpTILuGtvRPKgxMAdQh/Lf38tlNnedsSOXm1aZZFa3Vgm8N+Epk338gspvc1syAmOmnUtAFCQqShiUrgiA8SZqzYerMvGWAteprO+B89l2PdL2LXjYcbVyyyGiptCoKEsCaHIRgitNydEMYsEfHhlygEvMCuBqMzWrPlJgugeGD0GlhNW1gR9iq2GLQzRHYwfrSJeFBo1oQb0frIS7tBHy5WisaDJtJalOWOmEy5UuLAVSg8PHVXJ94yOEA9mdg9x4HV0x+bA5JSi0+29tVC59HPly+N9BvsYVRIGWsqW82Ki3OOpZuRtc7O4/YfhrNplTxBBCv6+SDqF5bCKJpNwXKV9t9peAFe39Jy18DMnZ8WnmYMKh4FP2YQUfE4XWnoXhPuRswSw6eRevNiYIYEZbP6YsLPlNY='

# Token caching
ACCESS_TOKEN = None
TOKEN_EXPIRY = None

def get_access_token():
    global ACCESS_TOKEN, TOKEN_EXPIRY
    
    if ACCESS_TOKEN and TOKEN_EXPIRY > datetime.now():
        print(f"Using cached token (expires {TOKEN_EXPIRY}): {ACCESS_TOKEN[:15]}...")  
        return ACCESS_TOKEN
        
    try:
        response = requests.post(
            'https://authenticator.azampay.co.tz/AppRegistration/GenerateToken',
            json={
                'appName': 'lightnet',
                'clientId': AZAM_CLIENT_ID,
                'clientSecret': AZAM_CLIENT_SECRET
            },
            timeout=30
        )
        response.raise_for_status()
        
        ACCESS_TOKEN = response.json()['data']['accessToken']
        TOKEN_EXPIRY = datetime.now() + timedelta(minutes=1)
        print(f"New token generated (expires {TOKEN_EXPIRY}): {ACCESS_TOKEN}")
        print(f"Truncated for logs: {ACCESS_TOKEN[:15]}...{ACCESS_TOKEN[-5:]}")
        return ACCESS_TOKEN
        
    except requests.exceptions.RequestException as e:
        app.logger.error(f"Token generation failed: {str(e)}")
        raise


@app.route('/make-payment', methods=['POST'])
def make_payment():
    try:
        print("\n=== STARTING PAYMENT PROCESS ===")
        print("Received request data:", request.json)

        # Generate voucher
        voucher_code = str(random.randint(10000000, 99999999))
        data = request.json
        location = data['location']
        duration_seconds = data['durationSeconds']
  #      mac_address = data['mac_address']
        print(f"Generated voucher: {voucher_code}")
        print(f"Duration seconds: {duration_seconds}")

        # Get access token
        try:
            print("\n[1/4] Getting access token...")
            token = get_access_token()
            print("Token retrieval successful")
        except Exception as e:
            print("!! TOKEN ERROR !!", str(e))
            return jsonify({
                'success': False,
                'error': 'Payment service unavailable',
                'details': str(e)
            }), 503

      

        # Prepare payload
        print("\n[3/4] Preparing payment payload...")
        payload = {
            'accountNumber': data['phone'],
            'amount': data['amount'],
            'currency': 'TZS',
            'externalId': str(uuid.uuid4()),
            'provider': data['provider'],
            'additionalProperties': {
                'voucher': voucher_code,
                'duration': duration_seconds,
                'location':location
   #             'mac_address':mac_address
            }
        }
        print("Payload (sanitized):", {**payload, 'additionalProperties': '...'})

        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {token}',  # No truncation
            'X-API-Key': 'none'                  # Exact header name
        }

        print("Headers:", headers)

        # Make payment request
        print("\n[4/4] Making payment request...")
   
        response = requests.post(
           'https://checkout.azampay.co.tz/azampay/mno/checkout',
            json=payload,
            headers=headers,  # Full untruncated headers
            timeout=15
        )

        print("\n=== PAYMENT RESPONSE ===")
        print("Status Code:", response.status_code)
        print("Headers:", dict(response.headers))
        print("Response Body:", response.text)

        response.raise_for_status()
        print("Payment request successful")

        return jsonify({
            'success': True,
            'voucherCode': voucher_code,
            'message': 'Payment initiated - use voucher now'
        })

    except requests.exceptions.RequestException as e:
        print("\n!! REQUEST ERROR !!")
        print("Error Type:", type(e).__name__)
        print("Error Message:", str(e))
        if hasattr(e, 'response') and e.response:
            print("Response Status:", e.response.status_code)
            print("Response Body:", e.response.text)
        delete_voucher(voucher_code)
        return jsonify({'success': False, 'error': str(e)}), 500
        
    except Exception as e:
        print("\n!! GENERAL ERROR !!")
        print("Error Type:", type(e).__name__)
        print("Error Message:", str(e))
        if 'voucher_code' in locals():
            delete_voucher(voucher_code)
        return jsonify({'success': False, 'error': str(e)}), 500



@app.route('/callback', methods=['POST'])
def callback():
    try:
        print("\n=== PAYMENT CALLBACK ===")

        # Extract full callback data for debugging
        callback_data = request.json
        print(f"Raw Callback Data: {callback_data}")

        # Extract additionalProperties
        additional_properties = callback_data.get('additionalProperties', {})

        if not additional_properties:
            print("Error: additionalProperties missing!")
            return jsonify({'success': False, 'error': 'Missing additionalProperties'}), 400

        # Extract voucher and duration
        voucher = additional_properties.get('voucher')
        location = additional_properties.get('location')
        amount = float(callback_data.get('amount', 100))

        duration = additional_properties.get('duration')
        mac_address = additional_properties.get('mac_address')
        status = callback_data.get('transactionstatus', '').lower()
        phone = callback_data.get('msisdn', '0750549026')
        print(f"Extracted Voucher: {voucher}, Duration: {duration}, Status: {status}")

        # Ensure voucher and duration are present
        if not voucher:
            print("Error: Voucher missing in additionalProperties!")
            return jsonify({'success': False, 'error': 'Missing voucher'}), 400

        if not duration:
            print("Error: Duration missing in additionalProperties!")
            return jsonify({'success': False, 'error': 'Missing duration'}), 400

        # Check payment status
        if status == 'success':
            print("CALLBACK SUCCESS. Proceeding to store voucher...")
        else:
            print("Payment failed - Deleting voucher")
            return jsonify({'success': False, 'error': 'Payment failed'}), 400

        # Store the voucher in the database
        print("Calling store_voucher function...")
        if not store_voucher(voucher, duration, location, amount, phone):
            print("store_voucher returned False! Voucher was not stored.")
            return jsonify({'success': False, 'error': 'Voucher creation failed'}), 500

        print("Voucher stored successfully!")
        return jsonify({'success': True}), 200

    except Exception as e:
        print("\n!! CALLBACK ERROR !!")
        print(f"Error Type: {type(e).__name__}")
        print(f"Error Message: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


def store_voucher(voucher, seconds, location, amount, phone):
    try:
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()
        print("Database connected successfully!")

        print(f"Inserting voucher: {voucher}, duration: {seconds}")

        # Insert into radcheck table
        cursor.execute('''
            INSERT INTO radcheck (username, attribute, op, value)
            VALUES (%s, 'Cleartext-Password', ':=', %s)
        ''', (voucher, 'ROCKY221122'))

        # Insert into radreply table
        cursor.execute('''
            INSERT INTO radreply (username, attribute, op, value)
            VALUES (%s, 'Session-Timeout', ':=', %s)
        ''', (voucher, seconds))

        # Insert into radreply table for speed limit (10M down / 10M up)
        cursor.execute('''
            INSERT INTO radreply (username, attribute, op, value)
            VALUES (%s, 'Mikrotik-Rate-Limit', ':=', %s)
        ''', (voucher, '10M/10M'))
         
         # Insert into vouchers table (this is your target)
        cursor.execute('''
              INSERT INTO vouchers (username, location, speed_limit, session_timeout, used) VALUES (%s, %s, %s, %s, 0)''',
         (voucher, location, '10M/10M',seconds))

        

        cursor.execute('''
            INSERT INTO payments (location, amount, duration, username, phone)
            VALUES (%s, %s, %s, %s, %s)
        ''', (location, amount, seconds, voucher, phone))

        conn.commit()
        print("Voucher stored successfully!")
        return True
    except mysql.connector.Error as e:
        print(f"DB Error: {str(e)}")  # Proper error logging
        return False
    finally:
        if conn.is_connected():
            cursor.close()
            conn.close()
            print("Database connection closed.")



def activate_voucher(voucher):
    try:
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()

        # Delete the X-Status row for the given voucher
        cursor.execute('''
            DELETE FROM radreply
            WHERE username = %s AND attribute = 'X-Status'
        ''', (voucher,))

        conn.commit()
        return cursor.rowcount > 0  # Returns True if a row was deleted
    except mysql.connector.Error as e:
        app.logger.error(f"DB Error: {e}")
        return False
    finally:
        if conn.is_connected():
            cursor.close()
            conn.close()
  

def delete_voucher(voucher):
    try:
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM radcheck WHERE username = %s', (voucher,))
        cursor.execute('DELETE FROM radreply WHERE username = %s', (voucher,))
        conn.commit()
        return True
    except mysql.connector.Error as e:
        app.logger.error(f"DB Error: {e}")
        return False
    finally:
        if conn.is_connected():
            cursor.close()
            conn.close()

# END OF AZAM

# Fetch Session Timeout from radreply
@app.route('/get_session_timeout', methods=['GET'])
def get_session_timeout():
    username = request.args.get('username')

    if not username:
        return jsonify({"error": "Username is required"}), 400

    try:
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)

        query = """
        SELECT value FROM radreply
        WHERE username = %s AND attribute = 'Session-Timeout';
        """
        cursor.execute(query, (username,))
        result = cursor.fetchone()

        session_timeout = int(result['value']) if result else 0
        return jsonify({"session_timeout": session_timeout})

    except mysql.connector.Error as err:
        return jsonify({"error": f"MySQL Error: {err}"}), 500

    finally:
        if db_connection.is_connected():
            cursor.close()
            db_connection.close()


# Fetch user information from radcheck
@app.route('/get_user_info', methods=['GET'])
def get_user_info():
    username = request.args.get('username')

    if not username:
        return jsonify({"error": "Username is required"}), 400

    try:
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)

        query = """
        SELECT id, username, location, speed_limit, session_timeout, mac_address, 
               first_login_time, expire_time, used, created_at, updated_at 
        FROM vouchers 
        WHERE username = %s
        """
        cursor.execute(query, (username,))
        voucher_info = cursor.fetchone()

        if not voucher_info:
            return jsonify({"error": "Voucher not found"}), 404

        return jsonify({"voucher_info": voucher_info})

    except mysql.connector.Error as err:
        return jsonify({"error": f"MySQL Error: {err}"}), 500

    finally:
        if db_connection.is_connected():
            cursor.close()
            db_connection.close()

@app.route('/vouchers', methods=['GET'])
def get_vouchers():
    try:
        # Establish database connection
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)  # Fetch results as dictionaries
        
        # SQL query to fetch all vouchers
        query = """
            SELECT id, username, location, speed_limit, session_timeout, 
                   mac_address, first_login_time, expire_time, used, 
                   created_at, updated_at 
            FROM vouchers
        """
        
        cursor.execute(query)
        vouchers = cursor.fetchall()
        
        # If no vouchers found, return a 404 JSON response
        if not vouchers:
            return jsonify({"message": "No vouchers found"}), 404
            
        return jsonify({"vouchers": vouchers})
    
    except mysql.connector.Error as err:
        return jsonify({"error": f"MySQL Error: {err}"}), 500
        
    finally:
        if 'db_connection' in locals() and db_connection.is_connected():
            cursor.close()
            db_connection.close()


@app.route('/valid_users', methods=['GET'])
def get_valid_users():
    location = request.args.get('location', None)  # Get location or set None

    try:
        # Establish database connection
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)  # Fetch results as dictionaries

        # SQL query to fetch users from 'location' table
        query = "SELECT username, speed_limit, session_timeout, location FROM location"
        params = []

        # Apply filter if location is provided
        if location:
            query += " WHERE location = %s"
            params.append(location)

        cursor.execute(query, params)
        users = cursor.fetchall()

        # If no users found, return a 404 JSON response
        if not users:
            return jsonify({"message": "No users found for this location"}), 404

        return jsonify({"users": users})

    except mysql.connector.Error as err:
        return jsonify({"error": f"MySQL Error: {err}"}), 500

    finally:
        if db_connection.is_connected():
            cursor.close()
            db_connection.close()


@app.route('/get-expire-time', methods=['GET'])
def get_expire_time():
    mac_address = request.args.get('mac', None)  # Get MAC address from query parameter

    # Validate MAC address
    if not mac_address:
        return jsonify({"error": "MAC address is required"}), 400

    try:
        # Establish database connection
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)

        # SQL query to fetch expire_time for the given MAC address
        query = "SELECT expire_time FROM vouchers WHERE mac_address = %s"
        params = [mac_address]

        cursor.execute(query, params)
        result = cursor.fetchone()

        # If no record is found, return a 404 JSON response
        if not result:
            return jsonify({"error": "MAC address not found"}), 404

        # Return expire_time in the response
        return jsonify({"expire_time": result['expire_time'].strftime('%Y-%m-%d %H:%M:%S')})

    except mysql.connector.Error as err:
        return jsonify({"error": f"MySQL Error: {err}"}), 500

    finally:
        if db_connection.is_connected():
            cursor.close()
            db_connection.close()
@app.route('/valid_users2')
def get_valid_users2():
    try:
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)

        # Modified query to check active_sessions table
        cursor.execute('''
            SELECT r.username, 
                   MAX(CASE WHEN r.attribute = 'Mikrotik-Rate-Limit' THEN r.value END) as speed_limit
            FROM radreply r
            WHERE r.attribute = 'Session-Timeout'
            AND r.username NOT IN (
                SELECT username 
                FROM active_sessions  # Changed to your custom table
            )
            GROUP BY r.username
        ''')

        users = cursor.fetchall()
        return jsonify({"users": users})

    except mysql.connector.Error as err:
        return jsonify({"error": f"MySQL Error: {err}"}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()

# Delete user from radcheck and radreply
@app.route('/delete_user', methods=['POST'])
def delete_user():
    username = request.json.get('username')

    if not username:
        return jsonify({"error": "Username is required"}), 400

    try:
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor()

        cursor.execute("DELETE FROM radcheck WHERE username = %s", (username,))
        cursor.execute("DELETE FROM radreply WHERE username = %s", (username,))
        db_connection.commit()

        return jsonify({"message": f"User {username} deleted successfully"})

    except mysql.connector.Error as err:
        return jsonify({"error": f"MySQL Error: {err}"}), 500

    finally:
        if db_connection.is_connected():
            cursor.close()
            db_connection.close()


# Fetch all payments
@app.route('/payments', methods=['GET'])
def payments():
    try:
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)

        query = "SELECT * FROM payments;"
        cursor.execute(query)
        payments = cursor.fetchall()

        return jsonify({"payments": payments})

    except mysql.connector.Error as err:
        return jsonify({"error": f"MySQL Error: {err}"}), 500

    finally:
        if db_connection.is_connected():
            cursor.close()
            db_connection.close()

@app.route('/active_sessions', methods=['GET'])
def get_active_sessions():
    try:
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor(dictionary=True)

        #  Query: Only MAC-address-style usernames, return latest per MAC
        query = """
            SELECT a.*
            FROM active_sessions a
            INNER JOIN (
                SELECT username, MAX(id) AS max_id
                FROM active_sessions
                WHERE username REGEXP '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$'
                GROUP BY username
            ) latest ON a.id = latest.max_id;
        """

        cursor.execute(query)
        sessions = cursor.fetchall()

        return jsonify({'active_sessions': sessions})

    except mysql.connector.Error as err:
        return jsonify({'error': f"MySQL Error: {err}"}), 500

    finally:
        if db_connection.is_connected():
            cursor.close()
            db_connection.close()


@app.route('/generate_users', methods=['POST'])
def generate_users():
    data = request.get_json()

    try:
        num_users = int(data.get('num_users', 0))
        num_days = float(data.get('num_days', 0))
        location = data.get('location')
        speed_limit = data.get('speed_limit')  # Get optional speed limit
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid input. Please provide numbers for num_users and num_days."}), 400

    if num_users <= 0 or num_days <= 0:
        return jsonify({"error": "num_users and num_days must be greater than zero."}), 400

    session_timeout_seconds = int(num_days * 24 * 60 * 60)

    try:
        db_connection = mysql.connector.connect(**db_config)
        cursor = db_connection.cursor()

        users_created = []

        for _ in range(num_users):
            username = ''.join(random.choices(string.digits, k=8))
            password = 'ROCKY221122'  # Warning: Hardcoded password for example

            # Insert credentials
            cursor.execute(
                "INSERT INTO radcheck (username, attribute, op, value) VALUES (%s, 'Cleartext-Password', ':=', %s)",
                (username, password)
            )

            # Insert session timeout
            cursor.execute(
                "INSERT INTO radreply (username, attribute, op, value) VALUES (%s, 'Session-Timeout', ':=', %s)",
                (username, session_timeout_seconds)
            )

           

            # Insert into location table with Mikrotik rate limit and session timeout
            cursor.execute(
               "INSERT INTO location (username, location, speed_limit, session_timeout) VALUES (%s, %s, %s, %s)",
               (username, location, speed_limit, session_timeout_seconds)
            )
               # Insert into vouchers table (this is your target)
            cursor.execute(
               "INSERT INTO vouchers (username, location, speed_limit, session_timeout, used) VALUES (%s, %s, %s, %s, 0)",
               (username, location, speed_limit, session_timeout_seconds)
            )

            # Insert speed limit if provided
            if speed_limit:
                cursor.execute(
                    "INSERT INTO radreply (username, attribute, op, value) VALUES (%s, 'Mikrotik-Rate-Limit', ':=', %s)",
                    (username, speed_limit)
                )

            users_created.append({
                "username": username,
                "password": password,
                "session_timeout": session_timeout_seconds,
                "speed_limit": speed_limit if speed_limit else "None"
            })

        db_connection.commit()
        return jsonify({
            "message": f"{num_users} users generated successfully.",
            "users": users_created
        }), 201

    except mysql.connector.Error as err:
        return jsonify({"error": f"MySQL Error: {err}"}), 500
    finally:
        if db_connection and db_connection.is_connected():
            cursor.close()
            db_connection.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) # Add debug=True for development
 
