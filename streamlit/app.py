<<<<<<< HEAD
# ---------------------------------
# Revenue Prediction Dashboard
# ---------------------------------

import streamlit as st
import pandas as pd
import joblib
import matplotlib.pyplot as plt
from sklearn.metrics import r2_score
import datetime
from snowflake_connection import fetch_daily_revenue, insert_prediction


st.set_page_config(page_title="Revenue ML Dashboard", layout="wide")

st.title("📊 Snowflake → ML → Streamlit Revenue Dashboard")

# ---------------------------------
# Load Data
# ---------------------------------
if st.button("🔄 Refresh Data"):
    st.cache_data.clear()

@st.cache_data
def load_data():
    return fetch_daily_revenue()

df = load_data()

# Convert date
df["ORDER_DATE"] = pd.to_datetime(df["ORDER_DATE"])

# Feature Engineering (MUST match training)
df = df.sort_values("ORDER_DATE")

df["day"] = df["ORDER_DATE"].dt.day
df["month"] = df["ORDER_DATE"].dt.month
df["day_of_week"] = df["ORDER_DATE"].dt.dayofweek


# ---------------------------------
# Load Model
# ---------------------------------
@st.cache_resource
def load_model():
    return joblib.load("ml/revenue_model.pkl")

model = load_model()

# ---------------------------------
# Predictions
# ---------------------------------
X = df[["TOTAL_ORDERS", "day", "month", "day_of_week"]]
df["PREDICTED_REVENUE"] = model.predict(X)

# ---------------------------------
# KPIs
# ---------------------------------
st.subheader("📌 Key Metrics")

col1, col2, col3 = st.columns(3)

col1.metric("Total Revenue", f"{df['TOTAL_REVENUE'].sum():,.2f}")
col2.metric("Average Daily Revenue", f"{df['TOTAL_REVENUE'].mean():,.2f}")
col3.metric("Total Orders", f"{df['TOTAL_ORDERS'].sum():,.0f}")

# ---------------------------------
# Figure 4: Orders vs Revenue
# ---------------------------------

st.subheader("📊 Orders vs Revenue Relationship")

fig2, ax2 = plt.subplots()

ax2.scatter(df["TOTAL_ORDERS"], df["TOTAL_REVENUE"], alpha=0.6)

ax2.set_xlabel("Total Orders")
ax2.set_ylabel("Total Revenue")
ax2.set_title("Orders vs Revenue Relationship")

st.pyplot(fig2)

# ---------------------------------
# Figure 5: Feature Importance
# ---------------------------------

st.subheader("📊 Feature Importance")

feature_names = ["TOTAL_ORDERS", "day", "month", "day_of_week"]

importance = model.coef_

importance_df = pd.DataFrame({
    "Feature": feature_names,
    "Importance": importance
})

importance_df = importance_df.sort_values(by="Importance", ascending=False)

fig3, ax3 = plt.subplots()

ax3.barh(importance_df["Feature"], importance_df["Importance"])

ax3.set_title("Feature Importance")

st.pyplot(fig3)

# ---------------------------------
# Figure 6: Model Performance Comparison
# ---------------------------------

st.subheader("📊 Model Performance Comparison")

models = ["Linear Regression", "Random Forest", "XGBoost"]

r2_scores = [0.949, 0.678, 0.692]

fig4, ax4 = plt.subplots()

ax4.bar(models, r2_scores)

ax4.set_ylabel("R² Score")

ax4.set_title("Model Performance Comparison")

st.pyplot(fig4)

# ---------------------------------
# Model Accuracy
# ---------------------------------
r2 = r2_score(df["TOTAL_REVENUE"], df["PREDICTED_REVENUE"])
st.write(f"### 📈 Model R² Score: {r2:.4f}")

# ---------------------------------
# Chart
# ---------------------------------
st.subheader("📈 Actual vs Predicted Revenue")

fig, ax = plt.subplots()
ax.plot(df["ORDER_DATE"], df["TOTAL_REVENUE"], label="Actual")
ax.plot(df["ORDER_DATE"], df["PREDICTED_REVENUE"], label="Predicted")
ax.legend()
plt.xticks(rotation=45)

st.pyplot(fig)

# ---------------------------------
# Prediction Tool
# ---------------------------------
st.subheader("🔮 Predict Revenue")

order_input = st.number_input("Enter Order Count", min_value=0, step=1)

if st.button("Predict"):
    today = datetime.datetime.today()

    input_data = pd.DataFrame({
        "TOTAL_ORDERS": [order_input],
        "day": [today.day],
        "month": [today.month],
        "day_of_week": [today.weekday()]
    })

    prediction = model.predict(input_data)

    # ✅ Store prediction in Snowflake
    insert_prediction(order_input, prediction[0])

    st.success(f"Predicted Revenue: {prediction[0]:,.2f}")
=======

>>>>>>> 96c9fe3c0f333a8ba3863b7cb6feed4c1b6e7112
