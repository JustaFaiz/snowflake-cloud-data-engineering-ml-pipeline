import snowflake.connector
import pandas as pd
import subprocess

def check_trigger():

    conn = snowflake.connector.connect(
        user="Faiz",
        password="Casperdabike1$",
        account="KSOTZHV-WAB12523",
        warehouse="ANALYTICS_WH",
        database="ECOMMERCE_DB",
        schema="TASKS",
        role="ACCOUNTADMIN"
    )

    query = """
    SELECT *
    FROM ML_TRAINING_TRIGGER
    WHERE STATUS = 'READY'
    """

    df = pd.read_sql(query, conn)

    conn.close()

    return df


df = check_trigger()

if len(df) > 0:

    print("Trigger detected → Retraining model")

    subprocess.run(["venv/Scripts/python", "ml/train_model.py"])

    print("Training complete")
