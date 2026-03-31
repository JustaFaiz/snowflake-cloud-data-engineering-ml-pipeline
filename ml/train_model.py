import pandas as pd
import snowflake.connector
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import r2_score, mean_absolute_error, mean_squared_error
import xgboost as xgb
import numpy as np
import joblib


# ---------------------------
# Snowflake Connection
# ---------------------------

def get_connection():

    conn = snowflake.connector.connect(
        user="Faiz",
        password="Casperdabike1$",
        account="KSOTZHV-WAB12523",
        warehouse="ANALYTICS_WH",
        database="ECOMMERCE_DB",
        schema="GOLD",
        role="ACCOUNTADMIN"
    )

    return conn


# ---------------------------
# Load Data from Snowflake
# ---------------------------

conn = get_connection()

query = """
SELECT *
FROM DAILY_REVENUE
"""

df = pd.read_sql(query, conn)

conn.close()

print("Data loaded from Snowflake:", df.shape)


# ---------------------------
# Feature Engineering
# ---------------------------

df["ORDER_DATE"] = pd.to_datetime(df["ORDER_DATE"])

df["day"] = df["ORDER_DATE"].dt.day
df["month"] = df["ORDER_DATE"].dt.month
df["day_of_week"] = df["ORDER_DATE"].dt.dayofweek


# ---------------------------
# Features / Target
# ---------------------------

X = df[["TOTAL_ORDERS", "day", "month", "day_of_week"]]
y = df["TOTAL_REVENUE"]


# ---------------------------
# Train/Test Split
# ---------------------------

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)


# ---------------------------
# Model Dictionary
# ---------------------------

models = {

    "Linear Regression": LinearRegression(),

    "Random Forest": RandomForestRegressor(
        n_estimators=200,
        random_state=42
    ),

    "XGBoost": xgb.XGBRegressor(
        n_estimators=200,
        learning_rate=0.1,
        max_depth=6
    )
}


# ---------------------------
# Train & Evaluate Models
# ---------------------------

results = []

best_model = None
best_score = -999


for name, model in models.items():

    model.fit(X_train, y_train)

    predictions = model.predict(X_test)

    r2 = r2_score(y_test, predictions)

    mae = mean_absolute_error(y_test, predictions)

    rmse = np.sqrt(mean_squared_error(y_test, predictions))

    results.append([name, r2, mae, rmse])

    print("\n", name)
    print("R2:", r2)
    print("MAE:", mae)
    print("RMSE:", rmse)

    if r2 > best_score:

        best_score = r2
        best_model = model


# ---------------------------
# Results Table
# ---------------------------

results_df = pd.DataFrame(
    results,
    columns=["Model", "R2", "MAE", "RMSE"]
)

print("\n===== MODEL COMPARISON =====")
print(results_df)


# ---------------------------
# Save Best Model
# ---------------------------

joblib.dump(best_model, "ml/revenue_model.pkl")

print("\nBest model saved.")


# ---------------------------
# Save Results to Snowflake
# ---------------------------

conn = get_connection()

cursor = conn.cursor()

for row in results:

    model_name, r2, mae, rmse = row

    cursor.execute("""
        INSERT INTO MODEL_PERFORMANCE
        VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP)
    """, (model_name, r2, mae, rmse))

conn.commit()

conn.close()

print("Model results stored in Snowflake.")
