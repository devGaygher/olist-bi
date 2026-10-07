-- 1_schema.sql
-- Projeto Olist BI: criacao das tabelas de camada bruta (raw)

USE olist;

DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    customer_id varchar(32) not null,
    customer_unique_id varchar(32) not null,
    customer_zip_code_prefix varchar(5),
    customer_city varchar(100),
    customer_state  char(2)
);

DROP TABLE IF EXISTS sellers;
CREATE TABLE sellers (
    seller_id varchar(32) not null,
    seller_zip_code_prefix varchar(5),
    seller_city varchar (100),
    seller_state char(2)
);

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id varchar(32) not null,
    customer_id varchar(32) not null,
    order_status varchar(32),
    order_purchase_timestamp datetime,
    order_approved_at datetime,
    order_delivered_carrier_date datetime,
    order_delivered_customer_date datetime,
    order_estimated_delivery_date datetime
);

DROP TABLE IF EXISTS geolocation;
CREATE TABLE geolocation (
    geolocation_zip_code_prefix varchar(5),
    geolocation_lat DECIMAL(18,15),
    geolocation_lng DECIMAL(18,15),
    geolocation_city varchar(100),
    geolocation_state char(2)
);

DROP TABLE IF EXISTS order_items;
CREATE TABLE order_items(
    order_id varchar(32) not null,
    order_item_id int not null,
    product_id varchar(32) not null,
    seller_id varchar (32) not null,
    shipping_limit_date datetime,
    price decimal(10,2) not null,
    freight_value decimal(10,2)
);

DROP TABLE IF EXISTS order_payments;
CREATE TABLE order_payments(
    order_id varchar(32) not null,
    payment_sequential int not null,
    payment_type varchar(20) not null,
    payment_installments int not null,
    payment_value decimal (10,2)
);

DROP TABLE IF EXISTS order_reviews;
CREATE TABLE order_reviews(
    review_id varchar(32) not null,
    order_id varchar(32) not null,
    review_score int not null,
    review_comment_title varchar(100),
    review_comment_message text,
    review_creation_date datetime,
    review_answer_timestamp datetime
);

DROP TABLE IF EXISTS products;
CREATE TABLE products(
    product_id varchar(32) not null,
    product_category_name varchar(100),
    product_name_length int,
    product_description_length int,
    product_photos_qty int,
    product_weight_g int,
    product_length_cm int,
    product_height_cm int,
    product_width_cm int
    
);

DROP TABLE IF EXISTS product_category_name_translation;
CREATE TABLE product_category_name_translation(
    product_category_name varchar(100),
    product_category_name_english varchar(100)
    
);
