import snowflake.connector

# Create connection
conn = snowflake.connector.connect(
    user="Faiz",
    password="Casperdabike1$",
    account="KSOTZHV-WAB12523",
    warehouse="ANALYTICS_WH"
)

cursor = conn.cursor()

print("\nConnected to Snowflake\n")

# Show current session context
cursor.execute("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA()")
print("Session Context:")
print(cursor.fetchall())

# Show tables visible to Python
print("\nTables visible to Python:\n")

cursor.execute("SHOW TABLES IN ECOMMERCE_DB.GOLD")
tables = cursor.fetchall()

for t in tables:
    print(t)

cursor.close()
conn.close()