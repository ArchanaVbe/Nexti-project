# Trip AI Backend

FastAPI + Google ADK Backend for Nexti Trip Planning App.

---

## Quick Setup Guide (For New Clones)

### 1. Open Terminal & Navigate to `backend`
```bash
cd backend
```

### 2. Create a Virtual Environment
- **Windows (PowerShell or CMD)**:
  ```bash
  python -m venv venv
  ```
- **macOS / Linux**:
  ```bash
  python3 -m venv venv
  ```

### 3. Activate the Virtual Environment
- **Windows (PowerShell)**:
  ```powershell
  .\venv\Scripts\Activate.ps1
  ```
  *(If you get an execution policy error, run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` first)*
- **Windows (Command Prompt)**:
  ```cmd
  venv\Scripts\activate.bat
  ```
- **macOS / Linux**:
  ```bash
  source venv/bin/activate
  ```

### 4. Install Dependencies
```bash
pip install -r requirements.txt
```

### 5. Setup Environment Variables (`.env`)
Create a `.env` file in the `backend/` directory with your API keys:
```env
GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-2.5-flash
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
PORT=8000
HOST=0.0.0.0
```

*(Note: Never commit `.env` or `serviceAccountKey.json` to GitHub)*

### 6. (Optional) Firebase Service Account Key
If you want the backend to write directly to Cloud Firestore:
- Download your Firebase Admin SDK service account JSON from Firebase Console -> Project Settings -> Service accounts.
- Save it as `backend/serviceAccountKey.json`.

---

## Running the Server

Start the server with hot-reload enabled:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
or:
```bash
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## Testing & Verifying
- Open Swagger API Documentation in browser: **[http://localhost:8000/docs](http://localhost:8000/docs)**
- Health check: **[http://localhost:8000/health](http://localhost:8000/health)**

---

## Connecting with Flutter Mobile App / Physical Device
If testing the Flutter app on a physical Android phone connected via USB:
```bash
adb reverse tcp:8000 tcp:8000
```
This forwards `http://localhost:8000` from the phone to your computer's FastAPI backend.
