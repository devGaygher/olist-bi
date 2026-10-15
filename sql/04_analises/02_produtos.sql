-- 2.1 Top 10 categorias por receita
SELECT COALESCE(t.product_category_name_english,p.product_category_name, 'sem_categoria') AS categoria,
COUNT(*) AS itens_vendidos,
COUNT(DISTINCT oi.order_id) As pedidos,
SUM(oi.price) AS receita
FROM order_items oi
JOIN orders AS o ON o.order_id = oi.order_id
JOIN products AS p ON p.product_id = oi.product_id
LEFT JOIN product_category_name_translation as t ON t.product_category_name = p.product_category_name
WHERE o.order_status NOT IN ('canceled','unavailable')
   AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY categoria
ORDER BY receita DESC
LIMIT 10;

-- 2.2 Nota média por categoria (1 review por pedido)
WITH review_unica AS (
    SELECT order_id, review_score
    FROM (SELECT
            order_id, review_score,
            ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC, review_creation_date DESC) AS rn
            FROM order_reviews
    ) AS x
    WHERE rn = 1
),
pedido_categoria AS ( 
    SELECT DISTINCT oi.order_id,
        COALESCE(t.product_category_name_english, p.product_category_name, 'sem_categoria') AS categoria
    FROM order_items AS oi
    JOIN orders AS o ON o.order_id = oi.order_id
    JOIN products AS p ON p.product_id = oi.product_id
    LEFT JOIN product_category_name_translation AS t ON t.product_category_name = p.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
)

SELECT pc.categoria, COUNT(*) AS pedidos_avaliados, ROUND(AVG(r.review_score), 2) AS nota_media
FROM pedido_categoria AS pc
JOIN review_unica AS r ON r.order_id = pc.order_id
GROUP BY pc.categoria
HAVING COUNT(*) >= 100
ORDER BY nota_media DESC;