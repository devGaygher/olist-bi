-- 6.1 Nota média: entregues no prazo x atrasados
WITH review_unica AS (
    SELECT order_id, review_score
    FROM (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id
                   ORDER BY review_answer_timestamp DESC, review_creation_date DESC) AS rn
        FROM order_reviews
    ) AS x
    WHERE rn = 1
)
SELECT CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 'No prazo' ELSE 'Atrasado' END AS situacao,
       COUNT(*) AS pedidos,
       ROUND(AVG(r.review_score), 2) AS nota_media
FROM orders AS o
JOIN review_unica AS r ON r.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY situacao;

-- 6.2 Nota média geral e cobertura das avaliações
-- A CTE vale só para a instrução em que foi declarada: o WITH é repetido aqui.
WITH review_unica AS (
    SELECT order_id, review_score
    FROM (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id
                   ORDER BY review_answer_timestamp DESC, review_creation_date DESC) AS rn
        FROM order_reviews
    ) AS x
    WHERE rn = 1
)
SELECT ROUND(AVG(r.review_score), 2) AS nota_media,
       COUNT(r.order_id) AS pedidos_com_review,
       COUNT(*) AS pedidos,
       ROUND(100 * COUNT(r.order_id) / COUNT(*), 1) AS pct_com_review
FROM orders AS o
LEFT JOIN review_unica AS r ON r.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';