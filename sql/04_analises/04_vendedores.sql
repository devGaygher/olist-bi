-- 4.1 Receita por faixa de vendedores
WITH por_vendedor AS (
    SELECT oi.seller_id, SUM(oi.price) AS receita
    FROM order_items AS oi
    JOIN orders AS o ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY oi.seller_id
),
ranqueado AS (
    SELECT seller_id, receita,
           ROW_NUMBER() OVER (ORDER BY receita DESC) AS posicao
    FROM por_vendedor
)
SELECT CASE WHEN posicao <= 10 THEN '1. Top 10'
            WHEN posicao <= 100 THEN '2. 11 a 100'
            ELSE '3. Demais' END AS faixa,
       COUNT(*) AS vendedores,
       SUM(receita) AS receita,
       ROUND(100 * SUM(receita) / SUM(SUM(receita)) OVER (), 1) AS pct_receita
FROM ranqueado
GROUP BY faixa
ORDER BY faixa;

-- 4.2 Curva acumulada dos 20 maiores vendedores
-- Uma CTE vale só para a instrução em que foi declarada: por isso as duas
-- CTEs são repetidas aqui, com o SELECT próprio da 4.2.
WITH por_vendedor AS (
    SELECT oi.seller_id, SUM(oi.price) AS receita
    FROM order_items AS oi
    JOIN orders AS o ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY oi.seller_id
),
ranqueado AS (
    SELECT seller_id, receita,
           ROW_NUMBER() OVER (ORDER BY receita DESC) AS posicao
    FROM por_vendedor
)
SELECT posicao, seller_id, receita,
       ROUND(100 * SUM(receita) OVER (ORDER BY posicao ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(receita) OVER (), 1) AS pct_acumulado
FROM ranqueado
ORDER BY posicao
LIMIT 20;

-- 4.3 Despacho, atraso e nota por vendedor (mínimo de 30 pedidos)
WITH review_unica AS (
    SELECT order_id, review_score
    FROM (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id
                   ORDER BY review_answer_timestamp DESC, review_creation_date DESC) AS rn
        FROM order_reviews
    ) AS x
    WHERE rn = 1
),
pedido_vendedor AS (
    SELECT seller_id, order_id,
           MIN(shipping_limit_date) AS limite_postagem,
           SUM(price) AS receita
    FROM order_items
    GROUP BY seller_id, order_id
),
metricas AS (
    SELECT pv.seller_id,
           COUNT(*) AS pedidos,
           SUM(pv.receita) AS receita,
           ROUND(100 * AVG(o.order_delivered_carrier_date <= pv.limite_postagem), 1) AS pct_postado_no_prazo,
           ROUND(100 * AVG(o.order_delivered_customer_date > o.order_estimated_delivery_date), 1) AS pct_atrasado,
           ROUND(AVG(r.review_score), 2) AS nota_media
    FROM pedido_vendedor AS pv
    JOIN orders AS o ON o.order_id = pv.order_id
    LEFT JOIN review_unica AS r ON r.order_id = pv.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY pv.seller_id
    HAVING COUNT(*) >= 30
)
SELECT seller_id, pedidos, receita, pct_postado_no_prazo, pct_atrasado, nota_media,
       CASE WHEN nota_media >= 4.3 AND pct_atrasado <= 5 THEN 'bom'
            WHEN nota_media < 3.5 OR pct_atrasado > 15 THEN 'problema'
            ELSE 'regular' END AS classificacao
FROM metricas
ORDER BY nota_media;

-- 4.4 Totais para os cartoes
WITH pedido_vendedor AS (
    SELECT seller_id, order_id, MIN(shipping_limit_date) AS limite_postagem
    FROM order_items
    GROUP BY seller_id, order_id
)
SELECT COUNT(DISTINCT pv.seller_id) AS vendedores_com_venda,
       COUNT(*) AS pares_pedido_vendedor,
       ROUND(100 * AVG(o.order_delivered_carrier_date <= pv.limite_postagem), 1) AS pct_postado_no_prazo
FROM pedido_vendedor AS pv
JOIN orders AS o ON o.order_id = pv.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';

-- 4.5 Vendedores por classificacao (so quem tem 30+ pedidos)
WITH review_unica AS (
    SELECT order_id, review_score
    FROM (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id
                   ORDER BY review_answer_timestamp DESC, review_creation_date DESC) AS rn
        FROM order_reviews
    ) AS x
    WHERE rn = 1
),
pedido_vendedor AS (
    SELECT seller_id, order_id,
           MIN(shipping_limit_date) AS limite_postagem,
           SUM(price) AS receita
    FROM order_items
    GROUP BY seller_id, order_id
),
metricas AS (
    SELECT pv.seller_id,
           SUM(pv.receita) AS receita,
           100 * AVG(o.order_delivered_customer_date > o.order_estimated_delivery_date) AS pct_atrasado,
           AVG(r.review_score) AS nota_media
    FROM pedido_vendedor AS pv
    JOIN orders AS o ON o.order_id = pv.order_id
    LEFT JOIN review_unica AS r ON r.order_id = pv.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY pv.seller_id
    HAVING COUNT(*) >= 30
)
SELECT CASE WHEN ROUND(nota_media, 2) >= 4.3 AND ROUND(pct_atrasado, 1) <= 5 THEN 'bom'
            WHEN ROUND(nota_media, 2) < 3.5 OR ROUND(pct_atrasado, 1) > 15 THEN 'problema'
            ELSE 'regular' END AS classificacao,
       COUNT(*) AS vendedores,
       ROUND(SUM(receita), 2) AS receita
FROM metricas
GROUP BY classificacao
ORDER BY classificacao;

