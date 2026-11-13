# Olist BI

Projeto de portfólio de análise de dados com SQL (MySQL), Power BI e Git. É uma simulação: eu faço o papel de analista de BI de um marketplace brasileiro e respondo a um pedido do diretor geral, que precisa explicar ao conselho como foi a operação em 2017 e 2018.

> A empresa, o diretor e o cenário são fictícios. Os dados são do dataset público *Brazilian E-Commerce Public Dataset by Olist*, no [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). O projeto não representa experiência de trabalho em nenhuma empresa. A licença do dataset está na página do Kaggle.

## O que foi entregue

O diretor pediu quatro coisas, e todas estão neste repositório:

- um painel no Power BI com 8 páginas: Visão executiva, Vendas, Produtos, Clientes, Vendedores, Logística, Satisfação e Pagamentos e pedidos;
- um relatório executivo de 1 página, em `docs/relatorio-executivo.pdf`;
- documentação em `docs/`: briefing, premissas, dicionário de dados e o registro das etapas;
- o código SQL e o projeto do Power BI, versionados.

O painel responde às 16 perguntas do briefing. A última, sobre lucro, não tem resposta: o dataset não traz custos, e o relatório diz isso em vez de estimar um número.

<!-- ![Visão executiva do painel](docs/img/visao-executiva.png) -->

## O que os dados mostram

Entre jan/2017 e ago/2018 foram R$ 13,45 milhões em vendas (sem frete) e 97.905 pedidos.

- O crescimento sobre o mesmo mês do ano anterior caiu de +687% em jan/2018 para +49% em ago/2018. A base de 2017 era pequena.
- A nota média é 4,29 quando o pedido chega no prazo e 2,57 quando atrasa. É uma associação, e os dados não provam a causa.
- Só 2,17% dos clientes voltaram a comprar. Como a janela é de 20 meses, esse número é um piso.

## Como o trabalho foi feito

Os CSVs entram numa camada bruta no MySQL, e as chaves foram criadas depois do profiling, porque o dataset tem duplicatas. As regras de negócio (pedido válido, período, receita sem frete, uma avaliação por pedido) foram escritas em `docs/premissas.md` antes de qualquer cálculo. As análises em SQL viram views, e o Power BI usa um modelo estrela em cima delas, com as medidas em DAX.

Os números do painel foram conferidos contra as consultas SQL, e o registro está em `docs/etapas-do-projeto.md`. O trabalho seguiu o fluxo de uma branch por assunto, com Pull Request e commits no padrão `tipo(escopo): resumo`.

## Estrutura

```
data/raw/    CSVs do Kaggle (não versionados)
docs/        briefing, premissas, dicionário de dados, etapas e relatório
sql/         schema, carga, chaves, profiling, análises e views
powerbi/     projeto do Power BI (PBIP) e tema
```

## Como reproduzir

Requisitos: MySQL 8.0, o cliente `mysql` e o Power BI Desktop. O projeto foi feito no Windows, com PowerShell.

1. Baixe os 9 CSVs do dataset no Kaggle e coloque em `data/raw/`.
2. Crie o banco e habilite a carga local de arquivos:

   ```sql
   CREATE DATABASE olist CHARACTER SET utf8mb4;
   SET GLOBAL local_infile = 1;
   ```

3. Rode os scripts da raiz do projeto, nesta ordem:

   ```
   mysql -u root -p -e "source sql/01_schema.sql"
   mysql -u root -p -D olist --local-infile=1 --show-warnings -e "source sql/02_carga.sql"
   mysql -u root -p -D olist -e "source sql/02b_chaves.sql"
   mysql -u root -p -D olist -e "source sql/02c_testes.sql"
   mysql -u root -p -D olist -t -e "source sql/03_profiling.sql"
   mysql -u root -p -D olist --default-character-set=utf8mb4 -e "source sql/05_views/05a_categorias_ptbr.sql"
   mysql -u root -p -D olist -e "source sql/05_views/05_views_bi.sql"
   ```

   O `02b_chaves.sql` não pode ser rodado duas vezes. Para repetir, recrie o banco a partir do `01_schema.sql`.

4. Abra `powerbi/olist-bi.pbip` no Power BI Desktop e aponte a conexão para o seu MySQL.

## Limites dos dados

- Não há custos nem despesas, então o lucro não pode ser calculado.
- A nota média representa só quem avaliou: 727 dos 97.905 pedidos (0,74%) não têm avaliação.
- Clientes, vendedores e produtos aparecem apenas como códigos.
- Só jan/2017 a ago/2018 tem dados completos.

## Autor

Rafael Gaygher
<!-- adicione aqui o link do seu LinkedIn -->
