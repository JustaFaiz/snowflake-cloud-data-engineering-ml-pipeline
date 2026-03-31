
/*BRONZE LAYER*/
CREATE OR REPLACE WAREHOUSE LOAD_WH
WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

SHOW WAREHOUSES;

CREATE OR REPLACE WAREHOUSE ANALYTICS_WH 
WITH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE;

    USE WAREHOUSE LOAD_WH;
SELECT CURRENT_WAREHOUSE();


CREATE OR REPLACE DATABASE ECOMMERCE_DB;

CREATE OR REPLACE SCHEMA ECOMMERCE_DB.BRONZE;
CREATE OR REPLACE SCHEMA ECOMMERCE_DB.SILVER;
CREATE OR REPLACE SCHEMA ECOMMERCE_DB.GOLD;

CREATE OR REPLACE FILE FORMAT ECOMMERCE_DB.BRONZE.CSV_FORMAT
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
NULL_IF = ('NULL', 'null');


/*ORDERS_RAW*/

CREATE OR REPLACE STAGE ECOMMERCE_DB.BRONZE.RAW_STAGE
FILE_FORMAT = ECOMMERCE_DB.BRONZE.CSV_FORMAT;

LIST @ECOMMERCE_DB.BRONZE.RAW_STAGE;

CREATE OR REPLACE TABLE ECOMMERCE_DB.BRONZE.ORDERS_RAW (
    order_id STRING,
    customer_id STRING,
    order_status STRING,
    order_purchase_timestamp STRING,
    order_approved_at STRING,
    order_delivered_carrier_date STRING,
    order_delivered_customer_date STRING,
    order_estimated_delivery_date STRING
);

USE WAREHOUSE LOAD_WH;

COPY INTO ECOMMERCE_DB.BRONZE.ORDERS_RAW
FROM @ECOMMERCE_DB.BRONZE.RAW_STAGE/olist_orders_dataset.csv
ON_ERROR = 'CONTINUE';

SELECT COUNT(*) FROM ECOMMERCE_DB.BRONZE.ORDERS_RAW;

/*CUSTOMERS_RAW*/

CREATE OR REPLACE TABLE ECOMMERCE_DB.BRONZE.CUSTOMERS_RAW (
    customer_id STRING,
    customer_unique_id STRING,
    customer_zip_code_prefix STRING,
    customer_city STRING,
    customer_state STRING
);

/*ORDER_ITEMS_RAW*/

CREATE OR REPLACE TABLE ECOMMERCE_DB.BRONZE.ORDER_ITEMS_RAW (
    order_id STRING,
    order_item_id INTEGER,
    product_id STRING,
    seller_id STRING,
    shipping_limit_date STRING,
    price NUMBER(10,2),
    freight_value NUMBER(10,2)
);

/*PRODUCTS_RAW*/

CREATE OR REPLACE TABLE ECOMMERCE_DB.BRONZE.PRODUCTS_RAW (
    product_id STRING,
    product_category_name STRING,
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);
/*PAYMENTS_RAW*/

CREATE OR REPLACE TABLE ECOMMERCE_DB.BRONZE.PAYMENTS_RAW (
    order_id STRING,
    payment_sequential INTEGER,
    payment_type STRING,
    payment_installments INTEGER,
    payment_value NUMBER(10,2)
);

/*Load ORDERS*/
COPY INTO ECOMMERCE_DB.BRONZE.ORDERS_RAW
FROM @ECOMMERCE_DB.BRONZE.RAW_STAGE/olist_orders_dataset.csv
ON_ERROR = 'CONTINUE';

/*Load CUSTOMERS*/
COPY INTO ECOMMERCE_DB.BRONZE.CUSTOMERS_RAW
FROM @ECOMMERCE_DB.BRONZE.RAW_STAGE/olist_customers_dataset.csv
ON_ERROR = 'CONTINUE';

/*Load ORDER_ITEMS*/
COPY INTO ECOMMERCE_DB.BRONZE.ORDER_ITEMS_RAW
FROM @ECOMMERCE_DB.BRONZE.RAW_STAGE/olist_order_items_dataset.csv
ON_ERROR = 'CONTINUE';

/*Load PRODUCTS*/
COPY INTO ECOMMERCE_DB.BRONZE.PRODUCTS_RAW
FROM @ECOMMERCE_DB.BRONZE.RAW_STAGE/olist_products_dataset.csv
ON_ERROR = 'CONTINUE';

/*Load PAYMENTS*/
COPY INTO ECOMMERCE_DB.BRONZE.PAYMENTS_RAW
FROM @ECOMMERCE_DB.BRONZE.RAW_STAGE/olist_order_payments_dataset.csv
ON_ERROR = 'CONTINUE';

/*Validation*/

SELECT COUNT(*) FROM ECOMMERCE_DB.BRONZE.ORDERS_RAW;
SELECT COUNT(*) FROM ECOMMERCE_DB.BRONZE.CUSTOMERS_RAW;
SELECT COUNT(*) FROM ECOMMERCE_DB.BRONZE.ORDER_ITEMS_RAW;
SELECT COUNT(*) FROM ECOMMERCE_DB.BRONZE.PRODUCTS_RAW;
SELECT COUNT(*) FROM ECOMMERCE_DB.BRONZE.PAYMENTS_RAW;

select * from ECOMMERCE_DB.BRONZE.ORDERS_RAW;





/* SILVER LAYER*/
/* Open Silver Schemna*/

/* standardizing formats */

CREATE OR REPLACE TABLE ECOMMERCE_DB.SILVER.ORDERS AS
SELECT
    order_id,
    customer_id,
    order_status,
    TO_TIMESTAMP(order_purchase_timestamp) AS order_purchase_ts,
    TO_TIMESTAMP(order_approved_at) AS order_approved_ts,
    TO_TIMESTAMP(order_delivered_carrier_date) AS order_carrier_ts,
    TO_TIMESTAMP(order_delivered_customer_date) AS order_delivered_ts,
    TO_TIMESTAMP(order_estimated_delivery_date) AS order_estimated_delivery_ts
FROM ECOMMERCE_DB.BRONZE.ORDERS_RAW
WHERE order_id IS NOT NULL;

SELECT * FROM ECOMMERCE_DB.SILVER.ORDERS ;

DESC TABLE ECOMMERCE_DB.SILVER.ORDERS;

/* Lists number of orders on that date */
SELECT
    DATE(order_purchase_ts) AS order_date,
    COUNT(*) AS orders
FROM ECOMMERCE_DB.SILVER.ORDERS
GROUP BY order_date;


/*Table Customers*/
CREATE OR REPLACE TABLE ECOMMERCE_DB.SILVER.CUSTOMERS AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    INITCAP(customer_city) AS customer_city, /*Generalizes city names*/    
    customer_state
FROM ECOMMERCE_DB.BRONZE.CUSTOMERS_RAW
WHERE customer_id IS NOT NULL;

select * from ECOMMERCE_DB.SILVER.CUSTOMERS LIMIT 10;

/*Order Table*/

CREATE OR REPLACE TABLE ECOMMERCE_DB.SILVER.ORDER_ITEMS AS
SELECT
    order_id,
    product_id,
    seller_id,
    CAST(price AS NUMBER(10,2)) AS price,   /* CAST standardizes values to 2 decimals*/
    CAST(freight_value AS NUMBER(10,2)) AS freight_value
FROM ECOMMERCE_DB.BRONZE.ORDER_ITEMS_RAW
WHERE order_id IS NOT NULL;
/*This sets the column values to always have 2 decimals*/

select * from ECOMMERCE_DB.SILVER.ORDER_ITEMS LIMIT 10;

SELECT COUNT(*) FROM ECOMMERCE_DB.SILVER.ORDERS;
SELECT COUNT(DISTINCT order_id) FROM ECOMMERCE_DB.SILVER.ORDERS; 
/*shows all values are unique*/

SELECT order_date, total_orders, total_revenue FROM ECOMMERCE_DB.GOLD.DAILY_REVENUE
ORDER BY order_date;







/*GOLD LAYER*/

USE WAREHOUSE ANALYTICS_WH;


/*Daily Revenue Table*/

CREATE OR REPLACE TABLE ECOMMERCE_DB.GOLD.DAILY_REVENUE AS
SELECT
    DATE(o.order_purchase_ts) AS order_date,
    SUM(oi.price) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM ECOMMERCE_DB.SILVER.ORDERS o
JOIN ECOMMERCE_DB.SILVER.ORDER_ITEMS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_date
ORDER BY order_date;

SELECT * FROM ECOMMERCE_DB.GOLD.DAILY_REVENUE ;

/*Customer Metrics Table*/
CREATE OR REPLACE TABLE ECOMMERCE_DB.GOLD.CUSTOMER_METRICS AS
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS total_spent,
    MIN(o.order_purchase_ts) AS first_order_date,
    MAX(o.order_purchase_ts) AS last_order_date
FROM ECOMMERCE_DB.SILVER.CUSTOMERS c
JOIN ECOMMERCE_DB.SILVER.ORDERS o
    ON c.customer_id = o.customer_id
JOIN ECOMMERCE_DB.SILVER.ORDER_ITEMS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id;

SELECT * FROM ECOMMERCE_DB.GOLD.CUSTOMER_METRICS LIMIT 500;
/*This displays no. of orders on each day*/


/*PRODUCT PERFORMANCE*/

CREATE OR REPLACE TABLE ECOMMERCE_DB.GOLD.PRODUCT_PERFORMANCE AS
SELECT
    oi.product_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.price) AS total_revenue,
    AVG(oi.price) AS avg_price
FROM ECOMMERCE_DB.SILVER.ORDER_ITEMS oi
GROUP BY oi.product_id
ORDER BY total_revenue DESC;

SELECT * FROM ECOMMERCE_DB.GOLD.PRODUCT_PERFORMANCE LIMIT 500;
/*Displays how products have done well*/
/*Displays how many products have been bought by repective product_id*/

SELECT
  order_date,
  total_orders,
  total_revenue
FROM ECOMMERCE_DB.GOLD.DAILY_REVENUE
ORDER BY order_date;

SELECT SUM(total_revenue) from ECOMMERCE_DB.GOLD.DAILY_REVENUE;


SELECT * FROM ECOMMERCE_DB.GOLD.DAILY_REVENUE;

SELECT * FROM ECOMMERCE_DB.GOLD.MODEL_PERFORMANCE;

SELECT * FROM ECOMMERCE_DB.GOLD.REVENUE_PREDICTIONS;
