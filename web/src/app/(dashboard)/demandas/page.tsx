import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";
import { ClickableRow } from "@/components/clickable-row";

export default function DemandasPage() {
  return (
    <>
      <Topbar title="Demandas" subtitle="Gestão de demandas da população" />

      <main className="content">
        <div className="kpis" style={{ gridTemplateColumns: "repeat(4,1fr)" }}>
          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <line x1="8" y1="6" x2="21" y2="6" />
                  <line x1="8" y1="12" x2="21" y2="12" />
                  <line x1="8" y1="18" x2="21" y2="18" />
                </svg>
              </div>
              <div className="lbl">Abertas</div>
            </div>
            <div className="num">217</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic amber">
                <svg className="ico" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="9" />
                  <polyline points="12 7 12 12 16 14" />
                </svg>
              </div>
              <div className="lbl">Em andamento</div>
            </div>
            <div className="num">187</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic green">
                <svg className="ico" viewBox="0 0 24 24">
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              </div>
              <div className="lbl">Concluídas (mês)</div>
            </div>
            <div className="num">1.031</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic red">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                </svg>
              </div>
              <div className="lbl">Atrasadas</div>
            </div>
            <div className="num">30</div>
          </div>
        </div>

        <div className="filters">
          <div className="ftab active" data-filter-group="dem">Todas</div>
          <div className="ftab" data-filter-group="dem">Abertas</div>
          <div className="ftab" data-filter-group="dem">Em andamento</div>
          <div className="ftab" data-filter-group="dem">Atrasadas</div>
          <div className="ftab" data-filter-group="dem">Concluídas</div>
          <div className="search">
            <input type="text" placeholder="🔍 Buscar protocolo, cidadão ou assunto…" />
          </div>
        </div>

        <div className="card">
          <h3>Fila de demandas — 1.248 no período</h3>
          <div className="tablewrap">
            <table>
              <thead>
                <tr><th>Protocolo</th><th>Cidadão</th><th>Assunto</th><th>Área</th><th>Canal</th><th>Prazo</th><th>Status</th></tr>
              </thead>
              <tbody>
                <ClickableRow href="/demandas/552">
                  <td>#2026-1042</td><td>Maria S. Lima</td><td>Falta de médico no posto</td><td>Saúde</td><td><span className="chip">WhatsApp</span></td><td>em 2 dias</td><td><span className="badge andamento">Em andamento</span></td>
                </ClickableRow>
                <ClickableRow href="/demandas/552">
                  <td>#2026-1041</td><td>João P. Alves</td><td>Buraco na via – Rua das Flores</td><td>Obras</td><td><span className="chip">Presencial</span></td><td>hoje</td><td><span className="badge critica">Crítica</span></td>
                </ClickableRow>
                <tr><td>#2026-1039</td><td>Ana C. Rocha</td><td>Vaga em creche</td><td>Educação</td><td><span className="chip">WhatsApp</span></td><td>em 5 dias</td><td><span className="badge aberta">Aberta</span></td></tr>
                <tr><td>#2026-1037</td><td>Carlos M.</td><td>Iluminação queimada</td><td>Infraestrutura</td><td><span className="chip">Telefone</span></td><td>em 3 dias</td><td><span className="badge andamento">Em andamento</span></td></tr>
                <tr><td>#2026-1034</td><td>Beatriz N.</td><td>Transporte escolar atrasado</td><td>Transporte</td><td><span className="chip">WhatsApp</span></td><td>atrasada</td><td><span className="badge atrasada">Atrasada</span></td></tr>
                <tr><td>#2026-1031</td><td>Rafael T.</td><td>Coleta de lixo irregular</td><td>Infraestrutura</td><td><span className="chip">Presencial</span></td><td>em 6 dias</td><td><span className="badge aberta">Aberta</span></td></tr>
                <tr><td>#2026-1029</td><td>Lúcia F.</td><td>Pedido de cadeira de rodas</td><td>Assistência</td><td><span className="chip">WhatsApp</span></td><td>concluída</td><td><span className="badge concluida">Concluída</span></td></tr>
                <tr><td>#2026-1026</td><td>Pedro H.</td><td>Poda de árvore</td><td>Obras</td><td><span className="chip">Telefone</span></td><td>em 4 dias</td><td><span className="badge andamento">Em andamento</span></td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
