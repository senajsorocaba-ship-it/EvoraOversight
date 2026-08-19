import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function ProjetosProposicoesPage() {
  return (
    <>
      <Topbar title="Projetos e Proposições" subtitle="Produção legislativa do mandato" />

      <main className="content">
        <div className="kpis" style={{ gridTemplateColumns: "repeat(4,1fr)" }}>
          <div className="kpi">
            <div className="row">
              <div className="ic green">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                  <polyline points="14 2 14 8 20 8" />
                </svg>
              </div>
              <div className="lbl">Projetos de lei</div>
            </div>
            <div className="num">11</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                  <polyline points="14 2 14 8 20 8" />
                </svg>
              </div>
              <div className="lbl">Indicações</div>
            </div>
            <div className="num">64</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic purple">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                  <polyline points="14 2 14 8 20 8" />
                </svg>
              </div>
              <div className="lbl">Requerimentos</div>
            </div>
            <div className="num">42</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic amber">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                  <polyline points="14 2 14 8 20 8" />
                </svg>
              </div>
              <div className="lbl">Emendas</div>
            </div>
            <div className="num">9</div>
          </div>
        </div>

        <div className="card">
          <h3>Produção legislativa — tramitação</h3>
          <div className="tablewrap">
            <table>
              <thead><tr><th>Nº</th><th>Tipo</th><th>Ementa</th><th>Fase</th><th>Data</th><th>Status</th></tr></thead>
              <tbody>
                <tr>
                  <td>PL 045/2026</td><td>Projeto de Lei</td><td>Programa Municipal de Saúde da Mulher</td>
                  <td><div className="progline" style={{ margin: 0 }}><div className="fase" style={{ width: 120 }}><div className="fasetrack"><div className="fasefill" style={{ width: "55%" }} /></div></div><span style={{ fontSize: 11, color: "var(--mut)" }}>Comissões</span></div></td>
                  <td>03/06</td><td><span className="badge tramitacao">Em tramitação</span></td>
                </tr>
                <tr>
                  <td>IND 312/2026</td><td>Indicação</td><td>Recapeamento da Rua das Flores</td>
                  <td><div className="progline" style={{ margin: 0 }}><div className="fase" style={{ width: 120 }}><div className="fasetrack"><div className="fasefill" style={{ width: "100%" }} /></div></div><span style={{ fontSize: 11, color: "var(--mut)" }}>Concluída</span></div></td>
                  <td>01/06</td><td><span className="badge atendida">Atendida</span></td>
                </tr>
                <tr>
                  <td>REQ 128/2026</td><td>Requerimento</td><td>Informações sobre contrato de merenda</td>
                  <td><div className="progline" style={{ margin: 0 }}><div className="fase" style={{ width: 120 }}><div className="fasetrack"><div className="fasefill" style={{ width: "25%" }} /></div></div><span style={{ fontSize: 11, color: "var(--mut)" }}>Aguardando</span></div></td>
                  <td>30/05</td><td><span className="badge protocolado">Protocolado</span></td>
                </tr>
                <tr>
                  <td>PL 041/2026</td><td>Projeto de Lei</td><td>Transparência em obras públicas</td>
                  <td><div className="progline" style={{ margin: 0 }}><div className="fase" style={{ width: 120 }}><div className="fasetrack"><div className="fasefill" style={{ width: "40%" }} /></div></div><span style={{ fontSize: 11, color: "var(--mut)" }}>1ª votação</span></div></td>
                  <td>24/05</td><td><span className="badge tramitacao">Em tramitação</span></td>
                </tr>
                <tr>
                  <td>IND 305/2026</td><td>Indicação</td><td>Área de lazer no Setor Norte</td>
                  <td><div className="progline" style={{ margin: 0 }}><div className="fase" style={{ width: 120 }}><div className="fasetrack"><div className="fasefill" style={{ width: "80%" }} /></div></div><span style={{ fontSize: 11, color: "var(--mut)" }}>Executivo</span></div></td>
                  <td>18/05</td><td><span className="badge encaminhada">Encaminhada</span></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
