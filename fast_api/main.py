from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
import joblib
import numpy as np
from typing import Optional
import os
from dotenv import load_dotenv
import mysql.connector
from mysql.connector import Error
import json
import time

app = FastAPI(title="Stroke Prediction API",
              description="API for predicting stroke risk based on health metrics",
              version="1.0")

# Database connection function
def get_db_connection(retries=10, delay=45):
    for attempt in range(retries):
        try:
            return mysql.connector.connect(
                host=os.getenv("MYSQL_HOST"),
                port=os.getenv("MYSQL_PORT"),
                database=os.getenv("MYSQL_DATABASE"),
                user=os.getenv("MYSQL_USER"),
                password=os.getenv("MYSQL_PASSWORD")
            )
        except Error as e:
            if attempt < retries - 1:
                time.sleep(delay)
            else:
                raise RuntimeError(f"Error connecting to MySQL: {e}")

# Create predictions table if not exists
def init_db():
    connection = None
    try:
        connection = get_db_connection()
        cursor = connection.cursor()
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS predictions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            gender VARCHAR(10),
            age FLOAT,
            hypertension TINYINT(1),
            heart_disease TINYINT(1),
            avg_glucose_level FLOAT,
            bmi FLOAT,
            smoking_status VARCHAR(20),
            name VARCHAR(100),
            country VARCHAR(50),
            province VARCHAR(50),
            probability FLOAT,
            risk_category VARCHAR(10),
            contributing_factors JSON,
            prediction_data JSON
        )
        """)
        connection.commit()
    except Error as e:
        raise RuntimeError(f"Error initializing database: {e}")
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

# Initialize database on startup
init_db()

# Load model - use absolute path
model_path = "/app/models/Logistic_Regression.pkl"
try:
    model = joblib.load(model_path)
except Exception as e:
    raise RuntimeError(f"Failed to load model: {str(e)}")

# Input schema
class PatientData(BaseModel):
    gender: str
    age: float
    hypertension: int
    heart_disease: int
    avg_glucose_level: float
    bmi: float
    smoking_status: str
    name: str
    country: str
    province: str
    age_group: Optional[str] = None
    bmi_category: Optional[str] = None
    glucose_category: Optional[str] = None
    age_hypertension: Optional[float] = None

def save_prediction_to_db(data: dict, prediction_result: dict):
    connection = None
    try:
        connection = get_db_connection()
        cursor = connection.cursor()
        insert_query = """
        INSERT INTO predictions (
            gender, age, hypertension, heart_disease,
            avg_glucose_level, bmi, smoking_status,
            name, country, province,
            probability, risk_category, contributing_factors,
            prediction_data
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(insert_query, (
            data['gender'],
            data['age'],
            int(data['hypertension']),
            int(data['heart_disease']),
            data['avg_glucose_level'],
            data['bmi'],
            data['smoking_status'],
            data['name'],
            data['country'],
            data['province'],
            prediction_result['probability'],
            prediction_result['risk_category'],
            json.dumps(prediction_result['contributing_factors']),
            json.dumps(data)
        ))
        connection.commit()
        return cursor.lastrowid
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

@app.get("/")
def read_root():
    return {"message": "Stroke Prediction API"}

@app.post("/predict")
def predict_stroke_risk(patient_data: PatientData):
    try:
        input_data = patient_data.dict()
        df = pd.DataFrame([input_data])

        # Feature engineering (if your model needs these columns)
        if input_data.get("age_group") is None:
            df["age_group"] = pd.cut(df["age"], bins=[0, 50, 80, 120],
                                     labels=["Young adult", "Middle-aged", "Very old"], right=False)
        if input_data.get("bmi_category") is None:
            df["bmi_category"] = pd.cut(df["bmi"], bins=[0, 18.5, 25, 30, 35, 40, 100],
                                        labels=["Underweight", "Healthy Weight", "Overweight",
                                                "Class 1 Obesity", "Class 2 Obesity", "Class 3 Obesity"], right=False)
        if input_data.get("glucose_category") is None:
            df["glucose_category"] = pd.cut(df["avg_glucose_level"],
                                            bins=[0, 70, 85, 100, 110, 126, 140, 300],
                                            labels=["Hypoglycemia", "Low Normal", "Normal", "Elevated",
                                                    "Pre-diabetic", "Borderline Diabetic", "Diabetic"], right=False)
        if input_data.get("age_hypertension") is None:
            df["age_hypertension"] = df["age"] * df["hypertension"]

        # Predict
        probability = float(model.predict_proba(df)[0][1])
        risk = "Low" if probability < 0.3 else "Medium" if probability < 0.7 else "High"

        # Contributing factors
        contributing_factors = ["Feature importance not available"]
        if hasattr(model, "feature_importances_"):
            importances = model.feature_importances_
            feature_names = getattr(model, "feature_names_in_", [])
            top_features = sorted(zip(feature_names, importances),
                                  key=lambda x: x[1], reverse=True)[:3]
            contributing_factors = [f[0] for f in top_features]

        prediction_result = {
            "probability": probability,
            "risk_category": risk,
            "contributing_factors": contributing_factors
        }

        prediction_id = save_prediction_to_db(input_data, prediction_result)
        prediction_result["prediction_id"] = prediction_id
        return prediction_result

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/predictions")
def get_predictions(limit: int = 10):
    connection = None
    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT * FROM predictions ORDER BY timestamp DESC LIMIT %s", (limit,))
        results = cursor.fetchall()
        for row in results:
            if row["contributing_factors"]:
                row["contributing_factors"] = json.loads(row["contributing_factors"])
            if row["prediction_data"]:
                row["prediction_data"] = json.loads(row["prediction_data"])
        return results
    except Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

@app.get("/model_info")
def get_model_info():
    try:
        info = {"model_type": str(type(model))}
        if hasattr(model, "best_params_"):
            info["best_params"] = model.best_params_
        if hasattr(model, "best_score_"):
            info["best_score"] = model.best_score_
        return info
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
