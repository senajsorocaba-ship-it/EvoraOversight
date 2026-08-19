// ÉVORA OVERSIGHT — Painel do Gabinete: navegação, modais e modo descanso.
// Maquete fiel ao PDF "Evora Telas 16x9" — dados de exemplo, sem backend
// (ao contrário do Dashboard Castelo/briefing.html, que já falam com o
// Supabase local). Comandos de voz e reconhecimento facial são decorativos
// aqui — não há STT nem biometria real implementados.

const TITULOS = {
  geral: ["Painel Executivo do Gabinete", "Vereadora Tatiane Costa · Período: últimos 30 dias"],
  demandas: ["Demandas", "Gestão de demandas da população"],
  atendimentos: ["Atendimentos", "Canais e histórico de atendimento ao cidadão"],
  fiscalizacoes: ["Fiscalizações", "Fiscalização do Executivo e registro de evidências"],
  projetos: ["Projetos e Proposições", "Produção legislativa do mandato"],
  contratos: ["Contratos e Licitações", "Monitoramento de contratos públicos"],
  denuncias: ["Denúncias", "Canal de denúncias e apuração"],
  indicadores: ["Indicadores", "Desempenho do gabinete em números"],
  documentos: ["Documentos", "Acervo documental do mandato"],
  agenda: ["Agenda", "Compromissos, sessões e vistorias"],
  relatorios: ["Relatórios", "Geração de relatórios e prestação de contas"],
  config: ["Configurações", "Usuários, segurança e infraestrutura"],
  demanda552: ["Demanda 552 — navegação por voz (A.T.)", "Regras 03 e 04 · paridade total: voz, texto ou clique · persistência de modalidade"],
};

function irPara(id) {
  document.querySelectorAll(".view").forEach(v => v.classList.remove("active"));
  const alvo = document.getElementById("view-" + id);
  if (alvo) alvo.classList.add("active");

  document.querySelectorAll(".sb-item").forEach(i => i.classList.remove("active"));
  const item = document.querySelector('.sb-item[data-view="' + id + '"]');
  if (item) item.classList.add("active");

  const t = TITULOS[id];
  if (t) {
    document.getElementById("tb-h1").textContent = t[0];
    document.getElementById("tb-p").textContent = t[1];
  }
  document.getElementById("content").scrollTop = 0;
  window.scrollTo(0, 0);
  fecharSidebarMobile();
}

function abrirSidebarMobile() {
  document.getElementById("sidebar").classList.add("open");
  document.getElementById("sb-backdrop").classList.add("show");
}
function fecharSidebarMobile() {
  document.getElementById("sidebar").classList.remove("open");
  document.getElementById("sb-backdrop").classList.remove("show");
}

// --------------------------------------------------------------- modais
function abrirModal(id) { document.getElementById(id).classList.add("show"); }
function fecharModal(id) { document.getElementById(id).classList.remove("show"); }

const DRILL = {
  demandas_recebidas: {
    kicker: "VOCÊ CLICOU EM",
    titulo: "Demandas recebidas · 1.248",
    fatos: [
      "Origem: Agente de Demandas (ADC), sob a Bia.",
      "Fontes: WhatsApp, presencial, telefone e portal do cidadão.",
      "Período: últimos 30 dias · atualizado hoje 08:15.",
      "Cálculo: soma dos protocolos recebidos no período.",
    ],
    resultados: ["#2026-1041 · Buraco na via — Rua das Flores", "#2026-1034 · Transporte escolar atrasado"],
    pergunta: '"Bia, por que as demandas subiram 12%?"',
    resposta: "As demandas subiram puxadas por Saúde (+18%) e Obras (+11%); 30 estão críticas há mais de 15 dias.",
    fontes: "ADC · ADG · AIM · Veritas",
  },
  demandas_concluidas: {
    kicker: "VOCÊ CLICOU EM", titulo: "Demandas concluídas · 1.031",
    fatos: ["Origem: Agente de Demandas (ADC).", "Cálculo: protocolos com status concluído no período.", "Meta interna de resolução: 80% — atual: 83%.", "Atualizado hoje 08:15."],
    resultados: ["#2026-1029 · Pedido de cadeira de rodas", "#2026-1017 · Poda de árvore concluída"],
    pergunta: '"Bia, qual área mais concluiu demandas?"',
    resposta: "Saúde concluiu 41% de tudo que foi resolvido no período, seguida por Infraestrutura (26%).",
    fontes: "ADC · base de demandas",
  },
  demandas_criticas: {
    kicker: "VOCÊ CLICOU EM", titulo: "Críticas pendentes · 30",
    fatos: ["Critério: sem atualização há mais de 15 dias ou marcadas como crítica.", "Origem: ADC, cruzado com prazos legais quando houver.", "Queda de 3% vs. período anterior."],
    resultados: ["#2026-1041 · Buraco na via — Rua das Flores (hoje)", "#2026-0999 · Falta de médico — 18 dias sem atualização"],
    pergunta: '"Bia, quais críticas vencem primeiro?"',
    resposta: "5 críticas vencem nos próximos 2 dias, todas em Saúde e Obras — sugiro priorizar essas na reunião de equipe.",
    fontes: "ADC · AAG",
  },
  fiscalizacoes: {
    kicker: "VOCÊ CLICOU EM", titulo: "Fiscalizações realizadas · 18",
    fatos: ["Origem: Agente de Fiscalização (AFEx), sob a Bia.", "Inclui visitas técnicas, análises contratuais e inspeções.", "6 pendências críticas em aberto."],
    resultados: ["Unidade Básica de Saúde Central · Crítica", "Contrato de Transporte Escolar · Crítica"],
    pergunta: '"Bia, quais fiscalizações viram requerimento?"',
    resposta: "2 fiscalizações críticas já têm minuta de requerimento pronta para protocolo, aguardando sua ciência.",
    fontes: "AFEx · Veritas",
  },
};

function abrirDrill(chave) {
  const d = DRILL[chave];
  if (!d) return;
  document.getElementById("drill-kicker").textContent = d.kicker;
  document.getElementById("drill-titulo").textContent = d.titulo;
  document.getElementById("drill-fatos").innerHTML = d.fatos.map(f => "<li>" + f + "</li>").join("");
  document.getElementById("drill-resultados").innerHTML = d.resultados.map(r => '<div class="result-row" onclick="irPara(\'demanda552\')">' + r + "</div>").join("");
  document.getElementById("drill-pergunta").textContent = d.pergunta;
  document.getElementById("drill-resposta").textContent = d.resposta;
  document.getElementById("drill-fontes").textContent = "Fontes consultadas: " + d.fontes;
  abrirModal("modal-drill");
}

function abrirDenunciaSigilosa(protocolo, tema) {
  document.getElementById("sig-protocolo").textContent = protocolo;
  document.getElementById("sig-pergunta").innerHTML =
    'Confirma abrir a denúncia <b>' + protocolo + ' — ' + tema + '</b>, classificada como <b>sigilosa</b>? Há outras pessoas no ambiente?';
  abrirModal("modal-sigilo");
}
function confirmarSigilo() {
  fecharModal("modal-sigilo");
  irPara("demanda552"); // placeholder de detalhe — mesma tela de exemplo do PDF
}

// --------------------------------------------------------------- modo descanso
let restTimer = null;
const REST_SEGUNDOS = 120; // "Tempo configurável: descanso após X segundos sem presença" (teto por alçada)

function reiniciarTimerDescanso() {
  clearTimeout(restTimer);
  restTimer = setTimeout(() => document.getElementById("rest").classList.add("show"), REST_SEGUNDOS * 1000);
}
function sairDoDescanso() {
  document.getElementById("rest").classList.remove("show");
  reiniciarTimerDescanso();
}

["mousemove", "keydown", "touchstart", "click", "scroll"].forEach(ev =>
  document.addEventListener(ev, () => {
    if (!document.getElementById("rest").classList.contains("show")) reiniciarTimerDescanso();
  }, { passive: true })
);

// --------------------------------------------------------------- init
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".sb-item[data-view]").forEach(item => {
    item.addEventListener("click", () => irPara(item.dataset.view));
  });
  document.getElementById("hamb").addEventListener("click", abrirSidebarMobile);
  document.getElementById("sb-backdrop").addEventListener("click", fecharSidebarMobile);
  document.querySelectorAll("[data-close-modal]").forEach(b =>
    b.addEventListener("click", () => fecharModal(b.dataset.closeModal))
  );
  document.getElementById("rest").addEventListener("click", sairDoDescanso);

  document.querySelectorAll(".ftab[data-filter-group]").forEach(tab => {
    tab.addEventListener("click", () => {
      const grupo = tab.dataset.filterGroup;
      document.querySelectorAll('.ftab[data-filter-group="' + grupo + '"]').forEach(t => t.classList.remove("active"));
      tab.classList.add("active");
    });
  });

  function tick() {
    const d = new Date(), p = n => String(n).padStart(2, "0");
    const el = document.getElementById("clock");
    if (el) el.textContent = p(d.getHours()) + ":" + p(d.getMinutes());
  }
  tick(); setInterval(tick, 10000);

  reiniciarTimerDescanso();
});
