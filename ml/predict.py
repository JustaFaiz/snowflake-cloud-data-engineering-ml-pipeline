import joblib
import os
import pandas as pd

# Locate model file
current_dir = os.path.dirname(__file__)
model_path = os.path.join(current_dir, "revenue_model.pkl")

# Load trained model
model = joblib.load(model_path)

print("Model loaded successfully.")

# Example input (simulate new day)
sample_input = pd.DataFrame({
    "TOTAL_ORDERS": [120],
    "day": [15],
    "month": [2],
    "day_of_week": [3]
})

# Predict
prediction = model.predict(sample_input)

print(f"Predicted Revenue: {prediction[0]:.2f}")
