import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";
import { DemandasTable } from "@/components/demandas-table";

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

        <DemandasTable />
      </main>
      <FooterLegal />
    </>
  );
}
