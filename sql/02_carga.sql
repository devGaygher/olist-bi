-- 02_carga.sql
-- Projeto Olist BI: carga dos CSVs nas tabelas da camada bruta
-- Rodar da raiz do projeto, com --local-infile=1

USE olist;

TRUNCATE TABLE customers;
LOAD DATA LOCAL INFILE 'data/raw/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

TRUNCATE TABLE sellers;
LOAD DATA LOCAL INFILE 'data/raw/olist_sellers_dataset.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

TRUNCATE TABLE geolocation;
LOAD DATA LOCAL INFILE 'data/raw/olist_geolocation_dataset.csv'
INTO TABLE geolocation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

TRUNCATE TABLE order_items;
LOAD DATA LOCAL INFILE 'data/raw/olist_order_items_dataset.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

TRUNCATE TABLE order_payments;
LOAD DATA LOCAL INFILE 'data/raw/olist_order_payments_dataset.csv'
INTO TABLE order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

TRUNCATE TABLE order_reviews;
LOAD DATA LOCAL INFILE 'data/raw/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(review_id, order_id, review_score, @title, @message,
 review_creation_date, review_answer_timestamp)
SET review_comment_title   = NULLIF(@title, ''),
    review_comment_message = NULLIF(@message, '');

TRUNCATE TABLE orders;
LOAD DATA LOCAL INFILE 'data/raw/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, order_purchase_timestamp,
 @approved, @carrier, @delivered, order_estimated_delivery_date)
SET order_approved_at             = NULLIF(@approved, ''),
    order_delivered_carrier_date  = NULLIF(@carrier, ''),
    order_delivered_customer_date = NULLIF(@delivered, '');

TRUNCATE TABLE products;
LOAD DATA LOCAL INFILE 'data/raw/olist_products_dataset.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, @category, @name_len, @desc_len, @photos,
 @weight, @length, @height, @width)
SET product_category_name      = NULLIF(@category, ''),
    product_name_length        = NULLIF(@name_len, ''),
    product_description_length = NULLIF(@desc_len, ''),
    product_photos_qty         = NULLIF(@photos, ''),
    product_weight_g           = NULLIF(@weight, ''),
    product_length_cm          = NULLIF(@length, ''),
    product_height_cm          = NULLIF(@height, ''),
    product_width_cm           = NULLIF(@width, '');

TRUNCATE TABLE product_category_name_translation;
LOAD DATA LOCAL INFILE 'data/raw/product_category_name_translation.csv'
INTO TABLE product_category_name_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- contagem de linhas de todas as tabelas

SELECT 'customers' AS tabela, COUNT(*) AS linhas FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation;

-- conferencia vazios virando null

SELECT
  SUM(order_approved_at IS NULL)             AS sem_aprovacao,
  SUM(order_delivered_carrier_date IS NULL)  AS sem_postagem,
  SUM(order_delivered_customer_date IS NULL) AS sem_entrega
FROM orders;
 
SELECT
  SUM(product_category_name IS NULL) AS sem_categoria,
  SUM(product_weight_g IS NULL)      AS sem_peso
FROM products;
 