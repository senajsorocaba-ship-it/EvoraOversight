// Chave usada em toda a "trava" do modo descanso (timer de inatividade e
// vigia de presença por rosto). Fica em sessionStorage — sobrevive a um F5
// (fechava uma brecha real: sem isso, recarregar a página destravava
// sozinho), mas some quando a aba/janela fecha de verdade.
export const CHAVE_TRAVADO = "evora-travado";

export function travar(router: { push: (href: string) => void }) {
  try {
    window.sessionStorage.setItem(CHAVE_TRAVADO, "1");
  } catch (e) {
    console.error("[trava-tela] não consegui marcar sessionStorage:", e);
  }
  router.push("/modo-descanso");
}

export function destravar() {
  try {
    window.sessionStorage.removeItem(CHAVE_TRAVADO);
  } catch (e) {
    console.error("[trava-tela] não consegui limpar sessionStorage:", e);
  }
}
