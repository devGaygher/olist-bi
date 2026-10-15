-- 7.1 Participação por pedidos e por valor (sem pagamentos de valor zero)
WITH base AS (
    SELECT p.order_id, p.payment_type, p.payment_installments, p.payment_value
    FROM order_payments AS p
    JOIN orders AS o ON o.order_id = p.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
      AND p.payment_value > 0
)
SELECT payment_type AS forma,
       COUNT(DISTINCT order_id) AS pedidos,
       ROUND(100 * COUNT(DISTINCT order_id) / (SELECT COUNT(DISTINCT order_id) FROM base), 1) AS pct_pedidos,
       ROUND(SUM(payment_value), 2) AS valor,
       ROUND(100 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 1) AS pct_valor
FROM base
GROUP BY payment_type
ORDER BY valor DESC;

-- 7.2 Parcelas do cartão de crédito (use o mesmo WITH base da 7.1)
WITH base AS (
    SELECT p.order_id, p.payment_type, p.payment_installments, p.payment_value
    FROM order_payments AS p
    JOIN orders AS o ON o.order_id = p.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
      AND p.payment_value > 0
)
SELECT payment_installments AS parcelas,
       COUNT(*) AS pagamentos,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM base
WHERE payment_type = 'credit_card' AND payment_installments > 0
GROUP BY parcelas
ORDER BY parcelas;

-- 7.3 Distribuição de status no período (todos os pedidos, sem filtro de validade)
SELECT order_status, COUNT(*) AS pedidos,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
WHERE order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY order_status
ORDER BY pedidos DESC;

-- 7.4 Taxa de pedidos perdidos por mês
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS mes,
       COUNT(*) AS pedidos,
       SUM(order_status = 'canceled') AS cancelados,
       SUM(order_status = 'unavailable') AS indisponiveis,
       ROUND(100 * SUM(order_status IN ('canceled', 'unavailable')) / COUNT(*), 2) AS pct_perdidos
FROM orders
WHERE order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY mes
ORDER BY mes;

-- 7.5 Taxa por estado do cliente (mínimo de 100 pedidos)
SELECT c.customer_state AS estado,
       COUNT(*) AS pedidos,
       ROUND(100 * SUM(o.order_status IN ('canceled', 'unavailable')) / COUNT(*), 2) AS pct_perdidos
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
WHERE o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY estado
HAVING COUNT(*) >= 100
ORDER BY pct_perdidos DESC;

