// ÉVORA OVERSIGHT — Painel do Gabinete: comportamento comum a todas as páginas.
// Cada tela do PDF é um arquivo .html separado (navegação por link real,
// sem SPA). Este arquivo só cuida do que é igual em todo lugar: menu mobile,
// modo descanso por inatividade, e o toggle visual dos filtros/abas.

function abrirSidebarMobile() {
  document.getElementById("sidebar").classList.add("open");
  document.getElementById("sb-backdrop").classList.add("show");
}
function fecharSidebarMobile() {
  document.getElementById("sidebar").classList.remove("open");
  document.getElementById("sb-backdrop").classList.remove("show");
}

// Modo descanso: "descanso após X segundos sem presença" (teto por alçada).
// Aqui, sem câmera/biometria real, o "reconhecimento facial" da página
// evora-modo-descanso.html é decorativo — clicar nela volta para a Visão Geral.
const REST_SEGUNDOS = 120;
let restTimer = null;
function iniciarTimerDescanso() {
  clearTimeout(restTimer);
  restTimer = setTimeout(() => { location.href = "Evora Modo Descanso.html"; }, REST_SEGUNDOS * 1000);
}

document.addEventListener("DOMContentLoaded", () => {
  const hamb = document.getElementById("hamb");
  if (hamb) hamb.addEventListener("click", abrirSidebarMobile);
  const backdrop = document.getElementById("sb-backdrop");
  if (backdrop) backdrop.addEventListener("click", fecharSidebarMobile);

  document.querySelectorAll(".ftab[data-filter-group]").forEach(tab => {
    tab.addEventListener("click", () => {
      const grupo = tab.dataset.filterGroup;
      document.querySelectorAll('.ftab[data-filter-group="' + grupo + '"]').forEach(t => t.classList.remove("active"));
      tab.classList.add("active");
    });
  });

  if (document.body.dataset.restTimer === "on") {
    iniciarTimerDescanso();
    ["mousemove", "keydown", "touchstart", "click", "scroll"].forEach(ev =>
      document.addEventListener(ev, iniciarTimerDescanso, { passive: true })
    );
  }
});
