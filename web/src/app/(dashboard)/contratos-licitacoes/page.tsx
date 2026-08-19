import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function ContratosLicitacoesPage() {
  return (
    <>
      <Topbar title="Contratos e Licitações" subtitle="Monitoramento de contratos públicos" />

      <main className="content">
        <div className="kpis" style={{ gridTemplateColumns: "repeat(4,1fr)" }}>
          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <rect x="7" y="3" width="10" height="4" rx="1" />
                  <path d="M9 5H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-3" />
                </svg>
              </div>
              <div className="lbl">Contratos monitorados</div>
            </div>
            <div className="num">48</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic green">
                <svg className="ico" viewBox="0 0 24 24">
                  <line x1="12" y1="1" x2="12" y2="23" />
                  <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
                </svg>
              </div>
              <div className="lbl">Valor total acompanhado</div>
            </div>
            <div className="num">R$ 312,4 mi</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic red">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                </svg>
              </div>
              <div className="lbl">Alertas de risco</div>
            </div>
            <div className="num">7</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic amber">
                <svg className="ico" viewBox="0 0 24 24">
                  <rect x="3" y="4" width="18" height="18" rx="2" />
                  <line x1="16" y1="2" x2="16" y2="6" />
                  <line x1="8" y1="2" x2="8" y2="6" />
                </svg>
              </div>
              <div className="lbl">Vencendo em 60 dias</div>
            </div>
            <div className="num">5</div>
          </div>
        </div>

        <div className="card">
          <h3>Contratos e licitações — monitoramento</h3>
          <div className="tablewrap">
            <table>
              <thead><tr><th>Contrato</th><th>Objeto</th><th>Fornecedor</th><th>Valor</th><th>Vigência</th><th>Risco</th></tr></thead>
              <tbody>
                <tr><td>CT 102/2024</td><td>Transporte escolar</td><td>TransVia Ltda.</td><td>R$ 8,4 mi</td><td>12/2026</td><td><span className="badge alto">ALTO</span></td></tr>
                <tr><td>CT 088/2025</td><td>Merenda escolar</td><td>Aliment Foods</td><td>R$ 12,1 mi</td><td>06/2026</td><td><span className="badge media">MÉDIO</span></td></tr>
                <tr><td>CT 145/2023</td><td>Obras – Av. Principal</td><td>Const. Horizonte</td><td>R$ 23,7 mi</td><td>09/2026</td><td><span className="badge alto">ALTO</span></td></tr>
                <tr><td>CT 061/2025</td><td>Coleta de resíduos</td><td>EcoLimp S.A.</td><td>R$ 15,9 mi</td><td>03/2027</td><td><span className="badge baixo">BAIXO</span></td></tr>
                <tr><td>CT 119/2024</td><td>Iluminação pública</td><td>LumenTech</td><td>R$ 6,2 mi</td><td>11/2026</td><td><span className="badge media">MÉDIO</span></td></tr>
              </tbody>
            </table>
          </div>
          <div className="modal-note" style={{ marginTop: 14 }}>O sistema cruza valores, aditivos e prazos com bases públicas e sinaliza desvios — base objetiva para fiscalizar o Executivo.</div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
