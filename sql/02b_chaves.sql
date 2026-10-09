-- ETAPA 7: chaves primárias e estrangeiras (decisões do Bloco 4 do profiling)
-- Rodar depois de 01_schema.sql e 02_carga.sql.

-- 1) CHAVES PRIMÁRIAS
ALTER TABLE customers ADD PRIMARY KEY (customer_id);
ALTER TABLE orders ADD PRIMARY KEY (order_id);
ALTER TABLE sellers ADD PRIMARY KEY (seller_id);
ALTER TABLE products ADD PRIMARY KEY (product_id);
ALTER TABLE order_items ADD PRIMARY KEY (order_id, order_item_id);
ALTER TABLE order_payments ADD PRIMARY KEY (order_id, payment_sequential);
ALTER TABLE order_reviews ADD PRIMARY KEY (review_id, order_id);
ALTER TABLE product_category_name_translation ADD PRIMARY KEY (product_category_name);

-- 2) CHAVES ESTRANGEIRAS (as 6 relações sem órfãos)
ALTER TABLE orders
  ADD CONSTRAINT fk_orders_customers
  FOREIGN KEY (customer_id) REFERENCES customers (customer_id);

ALTER TABLE order_items
  ADD CONSTRAINT fk_items_orders
  FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE order_items
  ADD CONSTRAINT fk_items_products
  FOREIGN KEY (product_id) REFERENCES products (product_id);

ALTER TABLE order_items
  ADD CONSTRAINT fk_items_sellers
  FOREIGN KEY (seller_id) REFERENCES sellers (seller_id);

ALTER TABLE order_payments
  ADD CONSTRAINT fk_payments_orders
  FOREIGN KEY (order_id) REFERENCES orders (order_id);

ALTER TABLE order_reviews
  ADD CONSTRAINT fk_reviews_orders
  FOREIGN KEY (order_id) REFERENCES orders (order_id);

-- DECISÃO DA ETAPA 7: sem FK products -> tradução (610 produtos sem categoria e
-- 2 categorias sem tradução); geolocation sem chave (52,6 linhas por CEP).

-- as PKs existem?
SELECT table_name, GROUP_CONCAT(column_name ORDER BY ordinal_position) AS colunas_pk
FROM information_schema.key_column_usage
WHERE table_schema = 'olist' AND constraint_name = 'PRIMARY'
GROUP BY table_name
ORDER BY table_name;

-- as FKs existem?
SELECT constraint_name, table_name, column_name,
       referenced_table_name, referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'olist' AND referenced_table_name IS NOT NULL
ORDER BY constraint_name;

-- a FK realmente barra órfão?
INSERT INTO order_items
  (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value)
VALUES
  ('pedido_que_nao_existe', 1, 'x', 'y', '2018-01-01 00:00:00', 10, 1);