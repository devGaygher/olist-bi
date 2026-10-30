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


-- 6.3 resumo para os cartões
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
SELECT COUNT(*) AS pedidos_com_item,
       COUNT(r.review_score) AS avaliados,
       SUM(r.review_score IS NULL) AS sem_avaliacao,
       ROUND(100 * SUM(r.review_score IS NULL) / COUNT(*), 2) AS pct_sem_avaliacao,
       ROUND(AVG(r.review_score), 2) AS nota_media,
       ROUND(100 * SUM(r.review_score IN (1, 2)) / COUNT(r.review_score), 2) AS pct_nota_baixa
FROM orders AS o
LEFT JOIN review_unica AS r ON r.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
  AND EXISTS (SELECT 1 FROM order_items AS i WHERE i.order_id = o.order_id);


-- 6.4 Pedidos por nota

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

SELECT r.review_score AS nota,
       COUNT(*) AS pedidos,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders AS o
JOIN review_unica AS r ON r.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
  AND EXISTS (SELECT 1 FROM order_items AS i WHERE i.order_id = o.order_id)
GROUP BY r.review_score
ORDER BY r.review_score;

-- 6.5 nota média por faixa de atraso

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

SELECT CASE
           WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN '1 No prazo'
           WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 3  THEN '2 Até 3 dias'
           WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 7  THEN '3 De 4 a 7 dias'
           WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 14 THEN '4 De 8 a 14 dias'
           ELSE '5 Mais de 14 dias'
       END AS faixa,
       COUNT(*) AS pedidos,
       COUNT(r.review_score) AS avaliados,
       ROUND(AVG(r.review_score), 2) AS nota_media
FROM orders AS o
LEFT JOIN review_unica AS r ON r.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
  AND EXISTS (SELECT 1 FROM order_items AS i WHERE i.order_id = o.order_id)
GROUP BY faixa
ORDER BY faixa;

-- 6.6 nota média por mes de compra

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

SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS mes,
       COUNT(r.review_score) AS avaliados,
       ROUND(AVG(r.review_score), 2) AS nota_media
FROM orders AS o
LEFT JOIN review_unica AS r ON r.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
  AND EXISTS (SELECT 1 FROM order_items AS i WHERE i.order_id = o.order_id)
GROUP BY mes
ORDER BY mes;

-- DECISÃO: a página Satisfação usa pedidos válidos com item (97.905), jan/2017 a ago/2018,
-- com a avaliação mais recente de cada pedido. A nota representa só quem avaliou:
-- 727 pedidos (0,74%) não têm avaliação. As faixas de atraso (cortes de 3, 7 e 14 dias)
-- são escolha da análise.