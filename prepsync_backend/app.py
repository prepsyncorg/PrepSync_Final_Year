import os
import requests
import json
from pypdf import PdfReader
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS

# --- App Setup ---
app = Flask(__name__)
basedir = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(basedir, 'database.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
CORS(app)

# --- AI CONFIGURATION ---
API_KEY = "AIzaSyCumg5YkJwqu64tw7V0oC8XjaPSnT-U7os"
CURRENT_MODEL = None 

def find_valid_model():
    """Asks Google which models are actually available for this Key"""
    global CURRENT_MODEL
    print("\n--- CHECKING AVAILABLE AI MODELS ---")
    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/models?key={API_KEY}"
        response = requests.get(url)
        
        if response.status_code != 200:
            print(f"Error fetching models: {response.text}")
            return None
            
        data = response.json()
        for model in data.get('models', []):
            if 'generateContent' in model.get('supportedGenerationMethods', []):
                print(f"✅ FOUND VALID MODEL: {model['name']}")
                CURRENT_MODEL = model['name']
                return
        print("❌ No text generation models found for this API Key.")
    except Exception as e:
        print(f"Error checking models: {e}")

# --- Database Models ---
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(80), nullable=True) 
    profile = db.relationship('Profile', backref='user', uselist=False)

class Profile(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    headline = db.Column(db.String(120), nullable=True)
    education = db.Column(db.String(120), nullable=True)
    university = db.Column(db.String(120), nullable=True)
    graduation_year = db.Column(db.String(4), nullable=True)
    city = db.Column(db.String(80), nullable=True)
    role_preference = db.Column(db.String(120), nullable=True)
    skills = db.Column(db.Text, nullable=True)
    # NEW COLUMN FOR SCORE (Default is 0)
    resume_score = db.Column(db.Integer, default=0) 
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False, unique=True)

# --- API Endpoints ---

# 1. RESUME ANALYZER ROUTE
@app.route('/api/analyze-resume', methods=['POST'])
def analyze_resume():
    if 'resume' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400
    
    file = request.files['resume']
    target_role = request.form.get('role', 'General Software Engineer')
    # CRITICAL: We need the user_id to know who to update
    user_id = request.form.get('user_id') 
    
    if file.filename == '':
        return jsonify({"error": "No file selected"}), 400

    try:
        # Extract Text from PDF
        reader = PdfReader(file)
        text = ""
        for page in reader.pages:
            text += page.extract_text()
            
        # Prompt for Gemini
        prompt = (
            f"Act as an expert ATS (Applicant Tracking System). "
            f"Analyze this resume for the role of: {target_role}.\n\n"
            f"Resume Text: {text[:10000]}...\n\n"
            f"IMPORTANT: Return ONLY a valid JSON object with this exact structure:\n"
            f"{{\n"
            f'  "score": 85,\n'
            f'  "feedback": ["Point 1", "Point 2", "Point 3"]\n'
            f"}}"
        )

        if not CURRENT_MODEL: find_valid_model()
        
        url = f"https://generativelanguage.googleapis.com/v1beta/{CURRENT_MODEL}:generateContent?key={API_KEY}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseMimeType": "application/json"} 
        }
        
        response = requests.post(url, json=payload)
        
        if response.status_code == 200:
            result_text = response.json()['candidates'][0]['content']['parts'][0]['text']
            clean_json = result_text.replace("```json", "").replace("```", "").strip()
            data = json.loads(clean_json)
            
            # --- SAVE SCORE TO DATABASE ---
            if user_id:
                profile = Profile.query.filter_by(user_id=user_id).first()
                if profile:
                    # Update the score in the database
                    new_score = data.get('score', 0)
                    profile.resume_score = new_score
                    db.session.commit()
                    print(f"Updated resume score for User {user_id} to {new_score}")
            
            return jsonify(data)
        else:
            print(f"AI Error: {response.text}")
            return jsonify({"error": "AI analysis failed"}), 500

    except Exception as e:
        print(f"Resume Error: {e}")
        return jsonify({"error": str(e)}), 500

# 2. CHATBOT ROUTE
@app.route('/api/chat', methods=['POST'])
def chat():
    if not CURRENT_MODEL: find_valid_model()
    data = request.get_json()
    user_message = data.get('message')
    if not user_message: return jsonify({"error": "No message"}), 400

    url = f"https://generativelanguage.googleapis.com/v1beta/{CURRENT_MODEL}:generateContent?key={API_KEY}"
    payload = {
        "contents": [{"parts": [{"text": f"You are PrepSync AI Career Coach. User: '{user_message}'. Answer clearly."}]}],
        "generationConfig": {"temperature": 0.7}
    }
    
    try:
        response = requests.post(url, json=payload)
        if response.status_code == 200:
            ai_reply = response.json()['candidates'][0]['content']['parts'][0]['text']
            return jsonify({"reply": ai_reply})
        return jsonify({"error": "AI Service Busy"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 3. AUTH & PROFILE ROUTES
@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()
    if User.query.filter_by(email=data['email']).first():
        return jsonify({"message": "User exists"}), 409
    new_user = User(email=data['email'], password=data['password'])
    db.session.add(new_user)
    db.session.commit()
    return jsonify({"user_id": new_user.id}), 201

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    user = User.query.filter_by(email=data['email']).first()
    if user and user.password == data['password']:
        return jsonify({"user_id": user.id, "profile_exists": user.profile is not None}), 200
    return jsonify({"message": "Invalid"}), 401

@app.route('/api/google-auth', methods=['POST'])
def google_auth():
    data = request.get_json()
    email = data.get('email')
    user = User.query.filter_by(email=email).first()
    if not user:
        user = User(email=email)
        db.session.add(user)
        db.session.commit()
    return jsonify({"user_id": user.id, "profile_exists": user.profile is not None}), 200

@app.route('/api/create-profile', methods=['POST'])
def create_profile():
    data = request.get_json()
    new_profile = Profile(
        user_id=data.get('user_id'), name=data.get('name'), headline=data.get('headline'),
        education=data.get('education'), university=data.get('university'),
        graduation_year=data.get('graduation_year'), city=data.get('city'),
        role_preference=data.get('role_preference'), skills=data.get('skills'),
        resume_score=0 # Initialize with 0
    )
    db.session.add(new_profile)
    db.session.commit()
    return jsonify({"message": "Created"}), 201

@app.route('/api/profile/<int:user_id>', methods=['GET'])
def get_profile(user_id):
    user = db.session.get(User, user_id)
    if not user or not user.profile:
        return jsonify({"message": "Not found"}), 404
    return jsonify({"name": user.profile.name.split(' ')[0]})

@app.route('/api/performance/<int:user_id>', methods=['GET'])
def get_performance(user_id):
    # Retrieve the REAL score from the database
    profile = Profile.query.filter_by(user_id=user_id).first()
    
    real_resume_score = profile.resume_score if profile else 0
    
    return jsonify({
        "resume_score": real_resume_score, # <--- SENDING REAL SCORE
        "aptitude_avg": 78,
        "interview_avg": 7.5,
        "communication_avg": 85
    }), 200

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    find_valid_model()
    print("\n--- PrepSync Backend Running (Resume Score Save) ---")
    app.run(host='0.0.0.0', port=5000, debug=True)