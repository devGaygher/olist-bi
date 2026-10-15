-- pergunta 1: quanto vendemos e quantos pedidos tivemos, mês a mês?

SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS mes,
    COUNT(DISTINCT oi.order_id) AS total_pedidos,
    SUM(oi.price) AS faturamento_total
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
    AND o.order_purchase_timestamp >= '2017-01-01' 
    AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY mes
ORDER BY mes;
-- between para meia noite e perderia as vendas do dia 31

-- 1.2 Conferência: total do período sem agrupar por mês
SELECT
    COUNT(DISTINCT oi.order_id) AS total_pedidos,
    SUM(oi.price) AS faturament_total
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')

-- between para meia noite e perderia as vendas do dia 31
    AND o.order_purchase_timestamp >= '2017-01-01' 
    AND o.order_purchase_timestamp < '2018-09-01';

-- pergunta 2: qual o crescimento em relacao ao ano anterior?

WITH mensal AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS mes, SUM(oi.price) AS receita
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
    AND o.order_purchase_timestamp >= '2017-01-01' 
    AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY mes),

comparado AS (
    SELECT mes, receita, LAG(receita, 12) OVER (ORDER BY mes) AS receita_ano_anterior
    FROM mensal
)
SELECT mes, receita, receita_ano_anterior,
ROUND((receita - receita_ano_anterior) / receita_ano_anterior * 100, 1) as var_pct
FROM comparado
WHERE mes >= '2018-01'
ORDER BY mes;

-- 1.4 Total jan-ago de cada ano
SELECT
YEAR(o.order_purchase_timestamp) AS ano,
COUNT(DISTINCT oi.order_id) AS total_pedidos,
SUM(oi.price) AS receita
FROM order_items oi
JOIN orders AS o ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp < '2018-09-01'
    AND MONTH(o.order_purchase_timestamp) BETWEEN 1 AND 8
GROUP BY ano
ORDER BY ano;

-- 1.5 Ticket médio por mês (receita ÷ pedidos)
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS mes,
    COUNT(DISTINCT o.order_id) AS pedidos,
    SUM(oi.price) AS receita,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS ticket_medio
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
    AND o.order_purchase_timestamp >= '2017-01-01' 
    AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY mes;

-- 1.6 Por dia da semana
SELECT DAYOFWEEK(o.order_purchase_timestamp) AS num_dia,
       ELT(DAYOFWEEK(o.order_purchase_timestamp), 'dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sab') AS dia,
       COUNT(DISTINCT oi.order_id) AS total_pedidos,
       SUM(oi.price) AS receita
FROM order_items AS oi
JOIN orders AS o ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY num_dia, dia
ORDER BY num_dia;


-- 1.7 Por hora; para o mapa de calor, acrescente o dia da semana ao SELECT e ao GROUP BY
SELECT HOUR(o.order_purchase_timestamp) AS hora,
       COUNT(DISTINCT oi.order_id) AS total_pedidos,
       SUM(oi.price) AS receita
FROM order_items AS oi
JOIN orders AS o ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY hora
ORDER BY hora;

-- BLACK FRIDAY 24 de nov de 2017 1.8 Vendas diárias contra a média dos 14 dias anteriores

WITH diario AS (
    SELECT
        DATE(o.order_purchase_timestamp) AS dia,
        COUNT(DISTINCT o.order_id) AS pedidos,
        SUM(oi.price) AS receita
    FROM order_items AS oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE  o.order_status NOT IN ('canceled', 'unavailable')
        AND o.order_purchase_timestamp >= '2017-10-15'
        AND o.order_purchase_timestamp <  '2017-12-01'
    GROUP BY dia
),

comparado AS (
    SELECT dia, pedidos, receita,
    AVG(receita) OVER (ORDER BY dia ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING) AS media_anterior
    FROM diario
)

SELECT dia, pedidos, receita, ROUND(media_anterior, 2) AS media_14_dias_anteriores,
ROUND (receita / media_anterior, 2) AS vezes_a_media
FROM comparado
WHERE dia >= '2017-11-17'
ORDER BY dia;

