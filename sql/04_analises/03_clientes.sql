-- 3.1 Clientes, pedidos e receita por estado
SELECT c.customer_state AS estado,
       COUNT(DISTINCT c.customer_unique_id) AS clientes,
       COUNT(DISTINCT oi.order_id) AS total_pedidos,
       SUM(oi.price) AS receita,
       ROUND(100 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 1) AS pct_receita
FROM order_items AS oi
JOIN orders AS o ON o.order_id = oi.order_id
JOIN customers AS c ON c.customer_id = o.customer_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY estado
ORDER BY receita DESC;

-- 3.2 Percentual de clientes com 2 ou mais dias de compra
WITH por_cliente AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT DATE(o.order_purchase_timestamp)) AS dias_compra
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS clientes,
       SUM(dias_compra >= 2) AS recompradores,
       ROUND(100 * SUM(dias_compra >= 2) / COUNT(*), 2) AS pct_recompra
FROM por_cliente;