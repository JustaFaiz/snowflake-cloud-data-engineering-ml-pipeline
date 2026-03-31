
import snowflake.connector
import pandas as pd


def get_snowflake_connection():
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


def fetch_daily_revenue():

    conn = get_snowflake_connection()
    cursor = conn.cursor()

    query = "SELECT * FROM DAILY_REVENUE"

    cursor.execute(query)

    df = pd.DataFrame.from_records(
        iter(cursor),
        columns=[col[0] for col in cursor.description]
    )

    cursor.close()
    conn.close()

    return df


def insert_prediction(order_count, predicted_value):

    conn = get_snowflake_connection()
    cursor = conn.cursor()

    insert_query = """
    INSERT INTO REVENUE_PREDICTIONS
    (PREDICTION_DATE, ORDER_COUNT, PREDICTED_REVENUE)
    VALUES (CURRENT_DATE(), %s, %s)
    """

    cursor.execute(insert_query, (order_count, float(predicted_value)))

    conn.commit()

    cursor.close()
    conn.close()

