import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_endpoint(method, endpoint, data=None):
    url = f"{BASE_URL}{endpoint}"
    try:
        if method == "GET":
            response = requests.get(url, params=data)
        else:
            response = requests.post(url, json=data)
        
        print(f"=== {method} {endpoint} ===")
        print(f"Status Code: {response.status_code}")
        if response.text:
            try:
                print(json.dumps(response.json(), indent=2))
            except:
                print(response.text)
        print()
        return response
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        print()

# Test the API
if __name__ == "__main__":
    # Test root endpoint
    test_endpoint("GET", "/")
    
    # Test model info
    test_endpoint("GET", "/model_info")
    
    # Test predictions
    test_data_1 = {
        "gender": "Male",
        "age": 45.5,
        "hypertension": 0,
        "heart_disease": 0,
        "avg_glucose_level": 95.2,
        "bmi": 26.8,
        "smoking_status": "never smoked",
        "name": "John Doe",
        "country": "United States",
        "province": "California"
    }
    
    test_endpoint("POST", "/predict", test_data_1)
    
    # Wait a moment for processing
    time.sleep(1)
    
    test_data_2 = {
        "gender": "Female",
        "age": 67.0,
        "hypertension": 1,
        "heart_disease": 1,
        "avg_glucose_level": 145.8,
        "bmi": 32.1,
        "smoking_status": "formerly smoked",
        "name": "Jane Smith",
        "country": "Canada",
        "province": "Ontario"
    }
    
    test_endpoint("POST", "/predict", test_data_2)
    
    # Test getting predictions
    test_endpoint("GET", "/predictions", {"limit": 5})
    
    # Test with optional fields
    test_data_3 = {
        "gender": "Other",
        "age": 35.0,
        "hypertension": 0,
        "heart_disease": 0,
        "avg_glucose_level": 88.5,
        "bmi": 22.3,
        "smoking_status": "never smoked",
        "name": "Alex Johnson",
        "country": "United Kingdom",
        "province": "London",
        "age_group": "Young adult",
        "bmi_category": "Healthy Weight",
        "glucose_category": "Normal"
    }
    
    test_endpoint("POST", "/predict", test_data_3)
    
    # Test predictions with limit
    test_endpoint("GET", "/predictions", {"limit": 3})
    
    # Test error case
    test_data_error = {
        "gender": "Male",
        "age": 45.5,
        "hypertension": 0,
        "heart_disease": 0,
        "avg_glucose_level": 95.2,
        "bmi": 26.8,
        "smoking_status": "never smoked",
        "name": "John Doe",
        "country": "United States"
        # Missing province field
    }
    
    test_endpoint("POST", "/predict", test_data_error)
