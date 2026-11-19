# RootFix · MongoDB: passo a passo

Arquivos usados:

| Arquivo | Onde roda | O que faz |
|---|---|---|
| `mongodb/01-criar-e-carregar.js` | mongosh | `use`, `createCollection` (2 collections), `insertMany` (13 documentos) e conferência |
| `mongodb/02-consultas.js` | mongosh | 3 relatórios: 2 com `find` e 1 com `aggregate` |
| `oracle/05-consultas-comparacao.sql` | SQL Developer | As mesmas 3 consultas em SQL, mais a conferência |

Tempo total: cerca de 40 minutos.

---

## Parte 1 · Deixar o MongoDB pronto (10 min)

Escolha **uma** das duas opções.

### Opção A: MongoDB no seu computador (mais simples)

1. Baixe o **MongoDB Community Server** em mongodb.com → Products → Community Server → Download (Windows, `.msi`).
2. Na instalação:
   - escolha **Complete**;
   - deixe marcado **"Install MongoD as a Service"**;
   - deixe marcado **"Install MongoDB Compass"**.
3. Abra o **MongoDB Compass**, clique em **"+ Add new connection"** e deixe a URI `mongodb://localhost:27017`.
4. Clique em **Save & Connect**.

### Opção B: MongoDB Atlas (na nuvem, grátis)

1. Crie uma conta em mongodb.com/atlas e um cluster **M0 (Free)**.
2. Em **Database Access**, crie um usuário com senha.
3. Em **Network Access**, clique em "Add IP Address" e depois em **"Allow access from anywhere"**.
4. Pegue a string de conexão:
   - no cluster, clique em **Connect** → **Compass**;
   - copie a string (`mongodb+srv://...`);
   - troque `<password>` pela sua senha.
5. No Compass, clique em **"+ Add new connection"**, cole a string e clique em **Save & Connect**.

### Abrir o mongosh dentro do Compass

Com a conexão aberta, clique em **`>_ MONGOSH`** na barra de baixo da janela (ou com o botão direito na conexão → "Open MongoDB shell"). É nesse terminal que os scripts vão ser colados.

---

## Parte 2 · Criar e carregar (5 min)

1. Abra `mongodb/01-criar-e-carregar.js` num editor (VS Code ou Bloco de Notas) e **copie o arquivo inteiro** (Ctrl+A, Ctrl+C).
2. Cole no mongosh (Ctrl+V) e aperte Enter. A primeira linha, `use rootfix`, cria o database e passa a usar ele.
3. No final, a **conferência** precisa mostrar:

   ```
   ==== Conferência da carga ====
   comunidades:  3
   problemas:    10
   [ { apoios: 14, observacoes: 5 } ]
   [ { membros: 9, comunicados: 3 } ]
   ```

4. **Print 1:** o comando colado e a conferência.
5. Clique no botão de atualizar do Compass (ou aperte F5). O database `rootfix` aparece na lateral com as collections `comunidades` e `problemas`.
6. **Print 2:** clique em `problemas` e mostre os documentos. Abra um deles e mostre o `autor`, os `apoios` e as `observacoes` incorporados.
7. **Print 3:** faça o mesmo em `comunidades`, mostrando o `gestor`, os `membros` e os `comunicados` incorporados.

O script pode ser colado de novo quantas vezes quiser: ele apaga e recria as duas collections.

---

## Parte 3 · Rodar os 3 relatórios no MongoDB (5 min)

1. Copie `mongodb/02-consultas.js` inteiro e cole no mongosh.
2. O resultado esperado é este:

**Relatório 1: feed da Vila Mariana - Metrô Ana Rosa**

| titulo | situacao | totalApoios |
|---|---|---|
| Bueiro entupido na Rua Vergueiro | NO FEED | 0 |
| Lixo acumulado na esquina da Rua França Pinto | NO FEED | 1 |
| Poste apagado na Rua Joaquim Távora | EM_ANDAMENTO | 2 |
| Buraco grande na Rua Domingos de Morais | RESOLVIDO | 2 |

**Relatório 2: mais apoiados ainda não adotados**

| titulo | comunidade | totalApoios |
|---|---|---|
| Banco quebrado na Praça Benedito Calixto | Pinheiros - Largo da Batata | 1 |
| Calçada quebrada perto do portão 10 do Ibirapuera | Vila Mariana - Parque Ibirapuera | 1 |
| Entulho abandonado no Largo da Batata | Pinheiros - Largo da Batata | 1 |
| Lixo acumulado na esquina da Rua França Pinto | Vila Mariana - Metrô Ana Rosa | 1 |
| Bueiro entupido na Rua Vergueiro | Vila Mariana - Metrô Ana Rosa | 0 |

**Relatório 3: problemas por comunidade e situação (aggregate)**

| comunidade | situacao | problemas | apoios |
|---|---|---|---|
| Pinheiros - Largo da Batata | ARQUIVADO | 1 | 2 |
| Pinheiros - Largo da Batata | NO FEED | 2 | 2 |
| Pinheiros - Largo da Batata | PENDENTE | 1 | 2 |
| Vila Mariana - Metrô Ana Rosa | EM_ANDAMENTO | 1 | 2 |
| Vila Mariana - Metrô Ana Rosa | NO FEED | 2 | 1 |
| Vila Mariana - Metrô Ana Rosa | RESOLVIDO | 1 | 2 |
| Vila Mariana - Parque Ibirapuera | EM_ANDAMENTO | 1 | 2 |
| Vila Mariana - Parque Ibirapuera | NO FEED | 1 | 1 |

"NO FEED" é o problema que ainda não foi adotado e continua só no feed da comunidade.

3. **Prints 4, 5 e 6:** um para cada relatório.

---

## Parte 4 · Rodar as mesmas consultas no Oracle (10 min)

1. No SQL Developer, rode de novo o `oracle/02-carga-dados-teste.sql` (F5). Assim os dados de teste voltam ao estado original, caso alguém tenha mexido neles pelo app.
2. Abra `oracle/05-consultas-comparacao.sql` e rode com **F5**. Aparece uma aba "Resultado da consulta" para cada consulta.
3. Confira que cada resultado é **igual** à tabela da Parte 3, e que a conferência mostra 3 comunidades, 10 problemas, 14 apoios, 5 observações, 9 membros e 3 comunicados.
4. **Prints 7, 8, 9 e 10:** os 3 relatórios e a conferência no Oracle.

Se algum número não bater, o mais provável é que os dados de teste tenham sido alterados pelo app. Rode o `02-carga-dados-teste.sql` de novo e repita o passo 2.

---

## Parte 5 · O que levar para o README (10 min)

### Mapa relacional → documental

| Oracle (tabela) | MongoDB | Como ficou | Por quê |
|---|---|---|---|
| `RF_COMUNIDADE` | collection `comunidades` | Documento principal | É a unidade que o app abre: nome, área e gestor |
| `RF_USUARIO` (gestor) | `comunidades.gestor` | **Incorporado** | Sempre aparece junto da comunidade e muda pouco |
| `RF_PARTICIPACAO` + `RF_USUARIO` (moradores) | `comunidades.membros[]` | **Incorporado** (array) | Uma comunidade de bairro tem poucos membros, e eles são lidos junto com ela |
| `RF_COMUNICADO` | `comunidades.comunicados[]` | **Incorporado** (array) | Poucos avisos por comunidade, sempre exibidos no topo dela |
| `RF_PROBLEMA` | collection `problemas` | Documento principal | É o que mais cresce e o que mais é consultado (feed, ranking, painel) |
| `RF_PROBLEMA.ID_COMUNIDADE` | `problemas.comunidade` (`_id` + `nome`) | **Referenciado**, com o nome copiado | Uma comunidade pode ter muitos problemas. Incorporar todos deixaria o documento da comunidade grande demais. O nome copiado evita uma busca extra só para mostrar o nome |
| `RF_USUARIO` (autor) | `problemas.autor` | **Incorporado** (nome e e-mail) | O feed mostra quem publicou, então o nome tem que vir junto |
| `RF_CATEGORIA` | `problemas.categoria` | **Incorporado** (só o nome) | Lista pequena e fixa; no documento só importa o nome |
| `RF_APOIO` | `problemas.apoios[]` + `totalApoios` | **Incorporado** | O voto é sempre lido junto com o problema. O total guardado deixa o ranking direto, sem contar na hora |
| `RF_OBSERVACAO` | `problemas.observacoes[]` | **Incorporado** | Os comentários aparecem sempre na tela do problema |
| `RF_FOTO_PROBLEMA` | não migrado | — | A foto é binária (BLOB) e fica no Oracle. No Mongo entrariam só os metadados |
| `RF_HISTORICO_STATUS`, `RF_NOTIFICACAO`, `RF_IDEMPOTENCIA` | não migrados | — | São controles das APIs, fora do escopo da representação documental |

### Correspondência Oracle ↔ MongoDB

Os documentos representam os mesmos registros da carga de teste do Oracle. A ligação é feita pelas chaves que são únicas no Oracle:
- **comunidade:** pelo `NOME`;
- **pessoa:** pelo `EMAIL`, que é UNIQUE em `RF_USUARIO`;
- **problema:** pelo `TITULO`.

A conferência dos dois lados (3 comunidades, 10 problemas, 14 apoios, 5 observações, 9 membros e 3 comunicados) prova que nada se perdeu na transição.

### Os 3 relatórios

Para cada relatório, coloque no README:
- a consulta do MongoDB;
- a consulta SQL equivalente;
- os dois prints, lado a lado;
- a frase "resultados iguais".

---

## Parte 6 · Na apresentação (23 a 27/11)

O PDF pede para **criar as collections e inserir os documentos na frente do professor** e depois **rodar os 3 relatórios comparando com o Oracle**. A ordem é:
1. Colar o `01-criar-e-carregar.js` no mongosh e mostrar a conferência.
2. Colar o `02-consultas.js`.
3. Rodar o `05-consultas-comparacao.sql` no SQL Developer e mostrar que os números batem.
4. Explicar o mapa acima: por que cada parte foi incorporada ou referenciada.
