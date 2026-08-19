import Link from "next/link";
import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function AprofundamentoPage() {
  return (
    <>
      <Topbar
        title="Painel Executivo — Aprofundamento Interativo"
        subtitle="Vereadora Tatiane Costa · clique em qualquer dado para abrir a janela de aprofundamento"
      />

      <main className="content">
        <div className="kpis">
          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <line x1="8" y1="6" x2="21" y2="6" />
                  <line x1="8" y1="12" x2="21" y2="12" />
                  <line x1="8" y1="18" x2="21" y2="18" />
                </svg>
              </div>
              <div className="lbl">Demandas recebidas</div>
            </div>
            <div className="num">1.248</div>
            <div className="delta up">+12% vs. período anterior</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic red">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                </svg>
              </div>
              <div className="lbl">Críticas pendentes</div>
            </div>
            <div className="num">30</div>
            <div className="delta down">-3% vs. período anterior</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic red">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                </svg>
              </div>
              <div className="lbl">Denúncias recebidas</div>
            </div>
            <div className="num">67</div>
          </div>
        </div>

        <div
          className="overlay show"
          style={{ position: "static", background: "none", padding: 0, display: "block", marginBottom: 18 }}
        >
          <div className="modal" style={{ maxWidth: 820, margin: "0 auto" }}>
            <div className="modal-h">
              <div>
                <span className="mk">VOCÊ CLICOU EM</span>
                <h2>Demandas recebidas · 1.248</h2>
              </div>
              <Link href="/">
                <button className="x">×</button>
              </Link>
            </div>
            <div className="modal-b">
              <div className="modal-cols">
                <div>
                  <div className="mini-h">Fundamentos do dado</div>
                  <ul className="mfacts">
                    <li>Origem: Agente de Demandas (ADC), sob a Bia.</li>
                    <li>Fontes: WhatsApp, presencial, telefone e portal do cidadão.</li>
                    <li>Período: últimos 30 dias · atualizado hoje 08:15.</li>
                    <li>Cálculo: soma dos protocolos recebidos no período.</li>
                  </ul>
                  <div className="mini-h" style={{ marginTop: 16 }}>Aprofundar o assunto</div>
                  <div className="search">
                    <input type="text" placeholder="🎤 Diga ou digite a demanda que quer abrir…" />
                  </div>
                  <div style={{ marginTop: 6 }}>
                    <Link className="result-row" style={{ display: "block" }} href="/demandas/552">
                      #2026-1041 · Buraco na via — Rua das Flores
                    </Link>
                    <Link className="result-row" style={{ display: "block" }} href="/demandas/552">
                      #2026-1034 · Transporte escolar atrasado
                    </Link>
                  </div>
                  <Link className="foot-link" href="/demandas">Abrir lista completa de demandas →</Link>
                </div>
                <div>
                  <div className="mini-h">Perguntar à Bia — voz ou texto</div>
                  <div className="mic-row">
                    <button className="mic-btn">🎤</button> &quot;Bia, por que as demandas subiram 12%?&quot;
                  </div>
                  <div className="bia-answer">
                    As demandas subiram puxadas por Saúde (+18%) e Obras (+11%); 30 estão críticas há mais de 15 dias.
                    <span className="src">Fontes consultadas: ADC · ADG · AIM · Veritas</span>
                  </div>
                  <div style={{ fontSize: 11, color: "var(--mut)" }}>
                    ↳ Nil acionada em segundo plano (somente leitura, sob alçada de campanha) para cruzar o dado eleitoral, quando autorizado.
                  </div>
                </div>
              </div>
              <div className="modal-actions">
                <span className="status-line">🔒 Modo pesquisa · somente leitura</span>
                <div style={{ fontSize: 12.5, color: "#cfe0f2" }}>
                  O dado consolidado vem de várias entradas sistêmicas e <b>não pode ser alterado por aqui</b>. Você pode:
                </div>
                <div className="act-btns">
                  <button>Sinalizar erro</button>
                  <button>Dado inválido</button>
                  <button>Pedir revisão →</button>
                </div>
                <div className="modal-note">Um pedido de revisão dispara alerta ao assessor de alçada superior.</div>
              </div>
              <div className="modal-note" style={{ marginTop: 12 }}>
                🔒 Toda tentativa de alteração gera aviso e fica registrada na Auditoria Interna (agente sob a Bia).
              </div>
            </div>
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
