# RootFix · PL/SQL (Banco de Dados)

Scripts para o Oracle, no mesmo usuário em que estão as tabelas do `script-bd.sql`.
Rode na ordem, com F5 ("Executar script") no SQL Developer.

| Ordem | Arquivo | O que faz | Pode repetir? |
|---|---|---|---|
| 1 | `01-objetos-plsql.sql` | Tabela de auditoria, 2 funções, 2 procedimentos, 2 gatilhos e 2 pacotes | Sim |
| 2 | `02-carga-dados-teste.sql` | Bloco anônimo com laços: gestores, comunidades, moradores, problemas, apoios, observações e comunicados de teste | Sim (apaga só os dados de teste antes) |
| 3 | `03-relatorio-comunidades.sql` | Bloco anônimo com cursores: relatório por comunidade | Sim (só lê) |
| 4 | `04-testes-plsql.sql` | 30 testes com `[OK]`/`[FALHOU]`; desfaz tudo com ROLLBACK no fim | Sim |

O resultado aparece na aba "Saída do DBMS".
Ela fica em Exibir → Saída do DBMS, e lá é preciso clicar no "+" e escolher a conexão.

## Objetos

- **RF_AUDITORIA_PROBLEMA:** registra cada INSERT, UPDATE ou DELETE em `RF_PROBLEMA`, com data, operação, valor antigo e valor novo.
- **Funções:**
  - `FN_DISTANCIA_KM`: distância em km entre duas coordenadas (fórmula de Haversine);
  - `FN_TOTAL_APOIOS`: total de apoios de um problema.
- **Procedimentos:**
  - `PRC_ADOTAR_PROBLEMA`: só o gestor da comunidade adota;
  - `PRC_ALTERAR_STATUS`: valida a mudança de status (PENDENTE → EM_ANDAMENTO → RESOLVIDO; ARQUIVADO a partir de PENDENTE ou EM_ANDAMENTO).
- **Gatilhos:**
  - `TRG_RF_PROBLEMA_AUDITORIA`: grava na tabela de auditoria;
  - `TRG_RF_PROBLEMA_ADOCAO`: preenche a data e o status da adoção quando vierem vazios.
- **Pacotes:**
  - `PKG_COMUNIDADE`: distância, membros, raio de 3 km e comunidades próximas;
  - `PKG_PROBLEMA`: apoios, adoção, status, contagem por status e ranking dos mais apoiados.

## Convivência com as APIs Java e .NET

- **Chamadas:** as APIs não chamam os procedimentos nem os pacotes.
- **Histórico de status:** nada aqui grava em `RF_HISTORICO_STATUS`, porque é a API .NET que grava lá.
- **Gatilho de auditoria:** dispara também quando as APIs gravam, mas nunca devolve erro.
- **Gatilho de adoção:** só preenche o que veio vazio. O Java já manda a data e o status, então para ele nada muda.
- **Dados de teste:**
  - os usuários de teste usam e-mail `@teste.rootfix.com` e senha `Rootfix@2026`, então também entram no app;
  - exemplos: `morador.ana@teste.rootfix.com` e `gestor.vilamariana@teste.rootfix.com`.
- **Se rodar o `script-bd.sql` de novo:** ele recria `RF_PROBLEMA`, e os gatilhos somem junto. Depois disso, rode o `01` e o `02` outra vez.

## Códigos de erro

| Código | Quando |
|---|---|
| -20001 | Problema não encontrado |
| -20002 | Quem tenta adotar ou mudar o status não é o gestor da comunidade |
| -20003 | Problema já adotado |
| -20004 | Problema ainda não adotado |
| -20005 | Status inválido |
| -20006 | Mudança de status não permitida |
| -20008 | Usuário ou comunidade não encontrado |
