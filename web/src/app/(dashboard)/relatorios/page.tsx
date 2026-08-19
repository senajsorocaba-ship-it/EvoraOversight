import Link from "next/link";
import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";
import { ClickableRow } from "@/components/clickable-row";

export default function RelatoriosPage() {
  return (
    <>
      <Topbar title="Relatórios" subtitle="Geração de relatórios e prestação de contas" />

      <main className="content">
        <div className="reports-grid">
          <div className="card">
            <h3>Modelos de relatório</h3>
            <div className="rmodel">
              <div className="ric" style={{ background: "rgba(43,84,120,.3)", color: "#8fbfe0" }}>
                <svg className="ico" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
              </div>
              <div className="rt"><b>Relatório Mensal de Atividades</b><span>Demandas, atendimentos, fiscalização e produção legislativa.</span></div>
              <Link href="/relatorio-mensal"><button>Gerar</button></Link>
            </div>
            <div className="rmodel">
              <div className="ric" style={{ background: "rgba(47,107,70,.3)", color: "#5fae7e" }}>
                <svg className="ico" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
              </div>
              <div className="rt"><b>Prestação de Contas à População</b><span>Versão pública, pronta para redes e portal.</span></div>
              <button>Gerar</button>
            </div>
            <div className="rmodel">
              <div className="ric" style={{ background: "rgba(154,107,21,.3)", color: "#e0a53a" }}>
                <svg className="ico" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
              </div>
              <div className="rt"><b>Relatório de Fiscalização</b><span>Consolida evidências e apontamentos por objeto.</span></div>
              <button>Gerar</button>
            </div>
            <div className="rmodel">
              <div className="ric" style={{ background: "rgba(111,74,134,.3)", color: "#b78fd6" }}>
                <svg className="ico" viewBox="0 0 24 24"><line x1="18" y1="20" x2="18" y2="10" /><line x1="12" y1="20" x2="12" y2="4" /><line x1="6" y1="20" x2="6" y2="14" /></svg>
              </div>
              <div className="rt"><b>Indicadores de Desempenho</b><span>KPIs do gabinete com gráficos e séries históricas.</span></div>
              <button>Gerar</button>
            </div>
          </div>
          <div className="card">
            <h3>Relatórios gerados</h3>
            <div className="tablewrap">
              <table style={{ minWidth: 340 }}>
                <thead><tr><th>Nome</th><th>Modelo</th><th>Data</th><th>Status</th></tr></thead>
                <tbody>
                  <ClickableRow href="/relatorio-mensal">
                    <td>Relatório Mensal – Maio/2026</td><td>Mensal de Atividades</td><td>01/06</td><td><span className="badge pronto">Pronto</span></td>
                  </ClickableRow>
                  <tr><td>Prestação de Contas – 1º semestre</td><td>Versão pública</td><td>30/05</td><td><span className="badge pronto">Pronto</span></td></tr>
                  <tr><td>Fiscalização – Transporte Escolar</td><td>Fiscalização</td><td>28/05</td><td><span className="badge pronto">Pronto</span></td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
        <div className="modal-note" style={{ marginTop: 14 }}>Um clique gera o relatório com os dados do período — sem montar planilha, sem copiar e colar. O exemplo a seguir mostra o resultado.</div>
      </main>
      <FooterLegal />
    </>
  );
}
