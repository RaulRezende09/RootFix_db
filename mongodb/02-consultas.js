// =====================================================================
// RootFix · Banco de Dados · MongoDB · 02 · Consultas e relatórios
// Grupo Rooted · Global Solution 2026/2 (CitizenTech)
// =====================================================================
// INTEGRANTES:
// Raul Rezende — RM564002
// Felipe Furlanetto — RM562766
// João Victor Caetano — RM562074
// Ryan Victor — RM565667
// João Victor Castelini — RM564115
// =====================================================================
// Pré-requisito: 01-criar-e-carregar.js.
// Como rodar: cole este arquivo inteiro no mongosh.
// Cada consulta tem a equivalente em SQL em oracle/05-consultas-comparacao.sql,
// com o mesmo resultado.
// =====================================================================

use rootfix

// ---------------------------------------------------------------------
// Relatório 1 — Feed de uma comunidade (find + sort)
// Problemas da "Vila Mariana - Metrô Ana Rosa", do mais recente para o
// mais antigo, com a situação e o total de apoios.
// ---------------------------------------------------------------------
print("==== Relatório 1: feed da Vila Mariana - Metrô Ana Rosa ====");
printjson(
  db.problemas.find(
    { "comunidade._id": "vila-mariana-ana-rosa" },
    { _id: 0, titulo: 1, situacao: { $ifNull: ["$status", "NO FEED"] }, totalApoios: 1 }
  ).sort({ criadoEm: -1 }).toArray()
);

// ---------------------------------------------------------------------
// Relatório 2 — Problemas mais apoiados ainda não adotados (find + sort + limit)
// Ajuda o gestor a decidir o que adotar.
// ---------------------------------------------------------------------
print("==== Relatório 2: mais apoiados ainda não adotados ====");
printjson(
  db.problemas.find(
    { adotado: false },
    { _id: 0, titulo: 1, comunidade: "$comunidade.nome", totalApoios: 1 }
  ).sort({ totalApoios: -1, titulo: 1 }).limit(5).toArray()
);

// ---------------------------------------------------------------------
// Relatório 3 — Problemas por comunidade e situação (aggregate)
// Quantos problemas há em cada situação e quantos apoios eles somam.
// ---------------------------------------------------------------------
print("==== Relatório 3: problemas por comunidade e situação (aggregate) ====");
printjson(
  db.problemas.aggregate([
    { $group: {
        _id: { comunidade: "$comunidade.nome", situacao: { $ifNull: ["$status", "NO FEED"] } },
        problemas: { $sum: 1 },
        apoios:    { $sum: "$totalApoios" }
    } },
    { $project: { _id: 0, comunidade: "$_id.comunidade", situacao: "$_id.situacao", problemas: 1, apoios: 1 } },
    { $sort: { comunidade: 1, situacao: 1 } }
  ]).toArray()
);
