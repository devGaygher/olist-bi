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

-- 3.1b Clientes unicos na base da 3.1 (so pedidos com item)
SELECT COUNT(DISTINCT c.customer_unique_id) AS clientes
FROM order_items AS oi
JOIN orders AS o ON o.order_id = oi.order_id
JOIN customers AS c ON c.customer_id = o.customer_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';

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

-- 3.3 Clientes que aparecem em mais de um estado
WITH por_cliente AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT c.customer_state) AS estados
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS clientes,
       SUM(estados >= 2) AS em_mais_de_um_estado
FROM por_cliente;

-- 3.4 Clientes por numero de dias de compra
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
SELECT CASE WHEN dias_compra >= 3 THEN '3 ou mais'
            ELSE CAST(dias_compra AS CHAR) END AS faixa,
       COUNT(*) AS clientes,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM por_cliente
GROUP BY faixa
ORDER BY faixa;

-- 3.5 Clientes e recompra por estado (gráfico 1: top 10; gráfico 3: top 5, por clientes)
WITH por_cliente_estado AS (
    SELECT c.customer_state AS estado,
           c.customer_unique_id,
           COUNT(DISTINCT DATE(o.order_purchase_timestamp)) AS dias_compra
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_state, c.customer_unique_id
)
SELECT estado,
       COUNT(*) AS clientes,
       SUM(dias_compra >= 2) AS recompradores,
       ROUND(100 * SUM(dias_compra >= 2) / COUNT(*), 2) AS pct_recompra
FROM por_cliente_estado
GROUP BY estado
ORDER BY clientes DESC;