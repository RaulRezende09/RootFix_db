// =====================================================================
// RootFix · Banco de Dados · MongoDB · 01 · Database, collections e carga
// Grupo Rooted · Global Solution 2026/2 (CitizenTech)
// =====================================================================
// INTEGRANTES:
// Raul Rezende — RM564002
// Felipe Furlanetto — RM562766
// João Victor Caetano — RM562074
// Ryan Victor — RM565667
// João Victor Castelini — RM564115
// =====================================================================
// Como rodar: abra o mongosh (no MongoDB Compass, aba "MONGOSH" na parte
// de baixo), copie este arquivo inteiro e cole. Pode rodar de novo: ele
// apaga e recria as collections.
//
// Os documentos representam os MESMOS dados da carga de teste do Oracle
// (oracle/02-carga-dados-teste.sql). A correspondência é feita pelas
// chaves naturais, que são únicas no Oracle:
//   comunidade -> NOME          (RF_COMUNIDADE.NOME)
//   pessoa     -> EMAIL         (RF_USUARIO.EMAIL, UNIQUE)
//   problema   -> TITULO + comunidade (RF_PROBLEMA.TITULO)
//
// Modelagem (detalhes no README):
//   comunidades: gestor, membros e comunicados INCORPORADOS
//   problemas:   comunidade REFERENCIADA (_id + nome), autor, categoria,
//                apoios e observações INCORPORADOS
// =====================================================================

// ---------------------------------------------------------------------
// 1. Selecionar / criar o database
// ---------------------------------------------------------------------
use rootfix

// ---------------------------------------------------------------------
// 2. Criar as 2 collections (apaga antes para o script ser reproduzível)
// ---------------------------------------------------------------------
db.comunidades.drop();
db.problemas.drop();

db.createCollection("comunidades");
db.createCollection("problemas");

// ---------------------------------------------------------------------
// 3. Pessoas da carga (mesmos nomes e e-mails do Oracle)
// ---------------------------------------------------------------------
var carla   = { nome: "Carla Mendes",         email: "gestor.vilamariana@teste.rootfix.com", organizacao: "Associação de Moradores da Vila Mariana" };
var paulo   = { nome: "Paulo Henrique Souza", email: "gestor.pinheiros@teste.rootfix.com",   organizacao: "Conselho Comunitário de Pinheiros" };

var ana     = { nome: "Ana Lima",        email: "morador.ana@teste.rootfix.com",    endereco: "Rua Domingos de Morais, 1200 - Vila Mariana" };
var bruno   = { nome: "Bruno Costa",     email: "morador.bruno@teste.rootfix.com",  endereco: "Rua Vergueiro, 2100 - Vila Mariana" };
var camila  = { nome: "Camila Rocha",    email: "morador.camila@teste.rootfix.com", endereco: "Rua França Pinto, 500 - Vila Mariana" };
var diego   = { nome: "Diego Martins",   email: "morador.diego@teste.rootfix.com",  endereco: "Rua Teodoro Sampaio, 1500 - Pinheiros" };
var elisa   = { nome: "Elisa Fernandes", email: "morador.elisa@teste.rootfix.com",  endereco: "Rua dos Pinheiros, 800 - Pinheiros" };
var fabio   = { nome: "Fábio Nunes",     email: "morador.fabio@teste.rootfix.com",  endereco: "Rua Cardeal Arcoverde, 1300 - Pinheiros" };

var pessoa = (p) => ({ nome: p.nome, email: p.email });  // resumo usado em autor/observação

// ---------------------------------------------------------------------
// 4. Collection "comunidades" — 3 documentos
// ---------------------------------------------------------------------
var textoMutirao = (nome) =>
  "Neste sábado, às 9h, faremos um mutirão de limpeza na comunidade " + nome +
  ". Tragam luvas; os sacos ficam por nossa conta.";

db.comunidades.insertMany([
  {
    _id: "vila-mariana-ana-rosa",
    nome: "Vila Mariana - Metrô Ana Rosa",
    descricao: "Ruas em volta do Metrô Ana Rosa, entre a Domingos de Morais e a Vergueiro.",
    localizacao: { type: "Point", coordinates: [-46.6383, -23.5812] },  // [longitude, latitude]
    raioKm: 3,
    gestor: carla,
    membros: [ana, bruno, camila],
    comunicados: [
      { titulo: "Mutirão de limpeza no sábado", texto: textoMutirao("Vila Mariana - Metrô Ana Rosa"),
        destacado: true, criadoEm: ISODate("2026-11-13T09:30:00Z") }
    ],
    criadaEm: ISODate("2026-11-13T09:00:00Z")
  },
  {
    _id: "pinheiros-largo-da-batata",
    nome: "Pinheiros - Largo da Batata",
    descricao: "Quarteirões entre o Largo da Batata, a Teodoro Sampaio e a Rua dos Pinheiros.",
    localizacao: { type: "Point", coordinates: [-46.6930, -23.5668] },
    raioKm: 3,
    gestor: paulo,
    membros: [diego, elisa, fabio],
    comunicados: [
      { titulo: "Mutirão de limpeza no sábado", texto: textoMutirao("Pinheiros - Largo da Batata"),
        destacado: false, criadoEm: ISODate("2026-11-13T09:31:00Z") }
    ],
    criadaEm: ISODate("2026-11-13T09:01:00Z")
  },
  {
    _id: "vila-mariana-ibirapuera",
    nome: "Vila Mariana - Parque Ibirapuera",
    descricao: "Entorno do portão 10 do Ibirapuera e da Av. Pedro Álvares Cabral.",
    localizacao: { type: "Point", coordinates: [-46.6576, -23.5874] },
    raioKm: 3,
    gestor: carla,
    membros: [ana, bruno, camila],
    comunicados: [
      { titulo: "Mutirão de limpeza no sábado", texto: textoMutirao("Vila Mariana - Parque Ibirapuera"),
        destacado: false, criadoEm: ISODate("2026-11-13T09:32:00Z") }
    ],
    criadaEm: ISODate("2026-11-13T09:02:00Z")
  }
]);

// ---------------------------------------------------------------------
// 5. Collection "problemas" — 10 documentos
//    situacao: status depois da adoção; sem adoção o problema fica
//    no feed (status null, como no Oracle).
// ---------------------------------------------------------------------
var anaRosa    = { _id: "vila-mariana-ana-rosa",      nome: "Vila Mariana - Metrô Ana Rosa" };
var pinheiros  = { _id: "pinheiros-largo-da-batata",  nome: "Pinheiros - Largo da Batata" };
var ibirapuera = { _id: "vila-mariana-ibirapuera",    nome: "Vila Mariana - Parque Ibirapuera" };

var problema = (d) => ({
  titulo: d.titulo,
  descricao: d.descricao,
  comunidade: d.comunidade,                       // referência (_id) + nome copiado
  autor: pessoa(d.autor),
  categoria: d.categoria,
  gravidadeIa: d.gravidade,
  justificativaIa: "Classificação de exemplo da carga de teste (PL/SQL).",
  localizacao: { type: "Point", coordinates: [d.lon, d.lat] },
  adotado: d.status !== null,
  status: d.status,
  apoios: d.apoios.map((p) => p.email),           // quem apoiou (1 por pessoa)
  totalApoios: d.apoios.length,
  observacoes: d.observacao
    ? [{ autor: pessoa(d.observacao.autor), texto: d.observacao.texto, criadaEm: d.criadoEm }]
    : [],
  criadoEm: d.criadoEm
});

db.problemas.insertMany([
  problema({ titulo: "Buraco grande na Rua Domingos de Morais",
    descricao: "Buraco de quase um metro na faixa da direita, na altura do número 1200. Carros desviam em cima da hora.",
    comunidade: anaRosa, autor: ana, categoria: "Buraco ou pavimento", gravidade: "ALTA",
    lat: -23.5838, lon: -46.6352, apoios: [bruno, camila],
    observacao: { autor: camila, texto: "Ontem um motoqueiro quase caiu aí." },
    status: "RESOLVIDO", criadoEm: ISODate("2026-11-13T10:01:00Z") }),

  problema({ titulo: "Poste apagado na Rua Joaquim Távora",
    descricao: "O poste em frente ao número 300 está apagado há duas semanas e a rua fica escura à noite.",
    comunidade: anaRosa, autor: bruno, categoria: "Iluminação pública", gravidade: "MEDIA",
    lat: -23.5801, lon: -46.6395, apoios: [ana, camila],
    observacao: null,
    status: "EM_ANDAMENTO", criadoEm: ISODate("2026-11-13T10:02:00Z") }),

  problema({ titulo: "Lixo acumulado na esquina da Rua França Pinto",
    descricao: "Sacos de lixo acumulados na esquina, fora do horário da coleta, atraindo ratos.",
    comunidade: anaRosa, autor: camila, categoria: "Lixo e limpeza", gravidade: "MEDIA",
    lat: -23.5902, lon: -46.6418, apoios: [ana],
    observacao: { autor: bruno, texto: "A coleta passou e não levou tudo." },
    status: null, criadoEm: ISODate("2026-11-13T10:03:00Z") }),

  problema({ titulo: "Bueiro entupido na Rua Vergueiro",
    descricao: "Quando chove forte a água sobe na calçada porque o bueiro está entupido de folhas.",
    comunidade: anaRosa, autor: bruno, categoria: "Bueiro e drenagem", gravidade: "ALTA",
    lat: -23.5788, lon: -46.6408, apoios: [],
    observacao: null,
    status: null, criadoEm: ISODate("2026-11-13T10:04:00Z") }),

  problema({ titulo: "Calçada quebrada perto do portão 10 do Ibirapuera",
    descricao: "Placas da calçada soltas e levantadas por raízes; difícil passar com cadeira de rodas.",
    comunidade: ibirapuera, autor: ana, categoria: "Calçada e acessibilidade", gravidade: "MEDIA",
    lat: -23.5870, lon: -46.6570, apoios: [bruno],
    observacao: { autor: camila, texto: "Minha mãe tropeçou aqui semana passada." },
    status: null, criadoEm: ISODate("2026-11-13T10:05:00Z") }),

  problema({ titulo: "Semáforo piscando na Av. Pedro Álvares Cabral",
    descricao: "Semáforo de pedestres em amarelo piscante desde segunda; travessia perigosa no horário de pico.",
    comunidade: ibirapuera, autor: camila, categoria: "Sinalização de trânsito", gravidade: "CRITICA",
    lat: -23.5880, lon: -46.6560, apoios: [ana, bruno],
    observacao: null,
    status: "EM_ANDAMENTO", criadoEm: ISODate("2026-11-13T10:06:00Z") }),

  problema({ titulo: "Buraco na ciclovia da Rua Teodoro Sampaio",
    descricao: "Buraco no meio da ciclovia, perto do cruzamento com a Rua Fradique Coutinho.",
    comunidade: pinheiros, autor: diego, categoria: "Buraco ou pavimento", gravidade: "ALTA",
    lat: -23.5655, lon: -46.6905, apoios: [elisa, fabio],
    observacao: { autor: fabio, texto: "Já vi dois ciclistas desviando para a pista dos carros." },
    status: "PENDENTE", criadoEm: ISODate("2026-11-13T10:07:00Z") }),

  problema({ titulo: "Entulho abandonado no Largo da Batata",
    descricao: "Restos de obra deixados no canto do largo há mais de dez dias.",
    comunidade: pinheiros, autor: elisa, categoria: "Lixo e limpeza", gravidade: "BAIXA",
    lat: -23.5670, lon: -46.6935, apoios: [diego],
    observacao: null,
    status: null, criadoEm: ISODate("2026-11-13T10:08:00Z") }),

  problema({ titulo: "Praça sem iluminação na Rua dos Pinheiros",
    descricao: "Os refletores da praça não acendem; à noite ninguém passa por lá.",
    comunidade: pinheiros, autor: fabio, categoria: "Iluminação pública", gravidade: "MEDIA",
    lat: -23.5692, lon: -46.6965, apoios: [diego, elisa],
    observacao: { autor: elisa, texto: "Foi aberta reclamação no 156 também." },
    status: "ARQUIVADO", criadoEm: ISODate("2026-11-13T10:09:00Z") }),

  problema({ titulo: "Banco quebrado na Praça Benedito Calixto",
    descricao: "Um dos bancos de madeira está com o assento partido e com pregos expostos.",
    comunidade: pinheiros, autor: elisa, categoria: "Praças e áreas verdes", gravidade: "BAIXA",
    lat: -23.5625, lon: -46.6880, apoios: [diego],
    observacao: null,
    status: null, criadoEm: ISODate("2026-11-13T10:10:00Z") })
]);

// Índice para o feed (problemas de uma comunidade, mais recentes primeiro)
db.problemas.createIndex({ "comunidade._id": 1, criadoEm: -1 });

// ---------------------------------------------------------------------
// 6. Conferência (compare com a seção 4 do oracle/05-consultas-comparacao.sql)
// ---------------------------------------------------------------------
print("==== Conferência da carga ====");
print("comunidades:  " + db.comunidades.countDocuments());   // esperado 3
print("problemas:    " + db.problemas.countDocuments());     // esperado 10
printjson(db.problemas.aggregate([
  { $group: { _id: null,
              apoios:      { $sum: "$totalApoios" },          // esperado 14
              observacoes: { $sum: { $size: "$observacoes" } } } },  // esperado 5
  { $project: { _id: 0, apoios: 1, observacoes: 1 } }
]).toArray());
printjson(db.comunidades.aggregate([
  { $group: { _id: null,
              membros:     { $sum: { $size: "$membros" } },      // esperado 9
              comunicados: { $sum: { $size: "$comunicados" } } } },  // esperado 3
  { $project: { _id: 0, membros: 1, comunicados: 1 } }
]).toArray());
