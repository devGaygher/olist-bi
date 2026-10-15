-- 5.1 Resumo do período
SELECT COUNT(*) AS pedidos_entregues,
    ROUND(100 * AVG(order_delivered_customer_date <= order_estimated_delivery_date), 1) AS pct_no_prazo,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 1) AS dias_ate_entrega
FROM orders
WHERE order_status NOT IN ('canceled', 'unavailable')
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01';


-- 5.1 Resumo do período
SELECT COUNT(*) AS pedidos_entregues,
    ROUND(100 * AVG(order_delivered_customer_date <= order_estimated_delivery_date), 1) AS pct_no_prazo,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 1) AS dias_ate_entrega
FROM orders
WHERE order_status NOT IN ('canceled', 'unavailable')
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01';


-- 5.2 Evolução mensal
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS mes,
    COUNT(*) AS pedidos_entregues,
    ROUND(100 * AVG(order_delivered_customer_date <= order_estimated_delivery_date), 1) AS pct_no_prazo,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 1) AS dias_ate_entrega
FROM orders
WHERE order_status NOT IN ('canceled', 'unavailable')
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY mes
ORDER BY mes;

-- 5.1 Resumo do período
SELECT COUNT(*) AS pedidos_entregues,
       ROUND(100 * AVG(order_delivered_customer_date <= order_estimated_delivery_date), 1) AS pct_no_prazo,
       ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 1) AS dias_ate_entrega
FROM orders
WHERE order_status NOT IN ('canceled', 'unavailable')
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01';


-- 5.2 Evolução mensal
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS mes,
       COUNT(*) AS pedidos_entregues,
       ROUND(100 * AVG(order_delivered_customer_date <= order_estimated_delivery_date), 1) AS pct_no_prazo,
       ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 1) AS dias_ate_entrega
FROM orders
WHERE order_status NOT IN ('canceled', 'unavailable')
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY mes
ORDER BY mes;


-- 5.3 Entrega e frete por estado (duas CTEs, uma por grão)
WITH entrega AS (
    SELECT c.customer_state AS estado,
           COUNT(*) AS pedidos_entregues,
           ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS dias_ate_entrega,
           ROUND(100 * AVG(o.order_delivered_customer_date <= o.order_estimated_delivery_date), 1) AS pct_no_prazo
    FROM orders AS o
    JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_state
),
frete AS (
    SELECT c.customer_state AS estado,
           ROUND(100 * SUM(oi.freight_value) / SUM(oi.price), 1) AS frete_pct_do_valor
    FROM order_items AS oi
    JOIN orders AS o ON o.order_id = oi.order_id
    JOIN customers AS c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_state
)
SELECT e.estado, e.pedidos_entregues, e.dias_ate_entrega, e.pct_no_prazo, f.frete_pct_do_valor
FROM entrega AS e
JOIN frete AS f ON f.estado = e.estado
ORDER BY e.dias_ate_entrega DESC;

