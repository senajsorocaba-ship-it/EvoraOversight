import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function IndicadoresPage() {
  return (
    <>
      <Topbar title="Indicadores" subtitle="Desempenho do gabinete em números" />

      <main className="content">
        <div className="kpis" style={{ gridTemplateColumns: "repeat(4,1fr)" }}>
          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <line x1="18" y1="20" x2="18" y2="10" />
                  <line x1="12" y1="20" x2="12" y2="4" />
                  <line x1="6" y1="20" x2="6" y2="14" />
                </svg>
              </div>
              <div className="lbl">Demandas/mês (média)</div>
            </div>
            <div className="num">248</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic green">
                <svg className="ico" viewBox="0 0 24 24">
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              </div>
              <div className="lbl">Taxa de resolução</div>
            </div>
            <div className="num">83%</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic purple">
                <svg className="ico" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="9" />
                  <polyline points="12 7 12 12 16 14" />
                </svg>
              </div>
              <div className="lbl">Tempo médio de resposta</div>
            </div>
            <div className="num">2h14</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic red">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                </svg>
              </div>
              <div className="lbl">Backlog crítico</div>
            </div>
            <div className="num">30</div>
          </div>
        </div>

        <div className="grid2">
          <div className="card">
            <h3>Evolução de demandas recebidas</h3>
            <svg className="linechart" viewBox="0 0 320 140" preserveAspectRatio="none">
              <polyline points="10,90 62,72 114,60 166,80 218,32 270,58" fill="none" stroke="#5fae7e" strokeWidth="2.5" />
              <g fill="#5fae7e">
                <circle cx="10" cy="90" r="3" /><circle cx="62" cy="72" r="3" /><circle cx="114" cy="60" r="3" />
                <circle cx="166" cy="80" r="3" /><circle cx="218" cy="32" r="3" /><circle cx="270" cy="58" r="3" />
              </g>
              <text x="10" y="132" fill="#8aa0bd" fontSize="10">Jan</text>
              <text x="58" y="132" fill="#8aa0bd" fontSize="10">Fev</text>
              <text x="108" y="132" fill="#8aa0bd" fontSize="10">Mar</text>
              <text x="160" y="132" fill="#8aa0bd" fontSize="10">Abr</text>
              <text x="212" y="132" fill="#8aa0bd" fontSize="10">Mai</text>
              <text x="264" y="132" fill="#8aa0bd" fontSize="10">Jun</text>
            </svg>
          </div>
          <div className="card">
            <h3>Demandas concluídas por mês</h3>
            <svg className="barchart" viewBox="0 0 320 140" preserveAspectRatio="none">
              <rect x="14" y="55" width="30" height="65" rx="3" fill="#5fae7e" />
              <rect x="66" y="48" width="30" height="72" rx="3" fill="#5fae7e" />
              <rect x="118" y="38" width="30" height="82" rx="3" fill="#5fae7e" />
              <rect x="170" y="60" width="30" height="60" rx="3" fill="#5fae7e" />
              <rect x="222" y="25" width="30" height="95" rx="3" fill="#5fae7e" />
              <rect x="274" y="42" width="30" height="78" rx="3" fill="#5fae7e" />
              <text x="20" y="132" fill="#8aa0bd" fontSize="10">Jan</text>
              <text x="72" y="132" fill="#8aa0bd" fontSize="10">Fev</text>
              <text x="124" y="132" fill="#8aa0bd" fontSize="10">Mar</text>
              <text x="176" y="132" fill="#8aa0bd" fontSize="10">Abr</text>
              <text x="228" y="132" fill="#8aa0bd" fontSize="10">Mai</text>
              <text x="280" y="132" fill="#8aa0bd" fontSize="10">Jun</text>
            </svg>
          </div>
        </div>

        <div className="grid2">
          <div className="card bars">
            <h3>Eficiência por dimensão</h3>
            <div className="brow"><div className="blbl"><span>Atendimento ao Cidadão</span><b>91%</b></div><div className="btrack"><div className="bfill" style={{ width: "91%", background: "#5fae7e" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Fiscalização</span><b>84%</b></div><div className="btrack"><div className="bfill" style={{ width: "84%", background: "#2b5478" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Transparência</span><b>76%</b></div><div className="btrack"><div className="bfill" style={{ width: "76%", background: "#6f4a86" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Controle Interno</span><b>68%</b></div><div className="btrack"><div className="bfill" style={{ width: "68%", background: "#e0a53a" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Segurança Institucional</span><b>55%</b></div><div className="btrack"><div className="bfill" style={{ width: "55%", background: "#e07a7a" }} /></div></div>
          </div>
          <div className="card">
            <h3>Demandas por área</h3>
            <div className="donut-wrap">
              <svg className="donut" viewBox="0 0 120 120">
                <g transform="rotate(-90 60 60)">
                  <circle cx="60" cy="60" r="52" fill="none" stroke="#2f6b46" strokeWidth="18" strokeDasharray="137.2 326.7" strokeDashoffset="0" />
                  <circle cx="60" cy="60" r="52" fill="none" stroke="#9a6b15" strokeWidth="18" strokeDasharray="91.5 326.7" strokeDashoffset="-137.2" />
                  <circle cx="60" cy="60" r="52" fill="none" stroke="#2b5478" strokeWidth="18" strokeDasharray="49.0 326.7" strokeDashoffset="-228.7" />
                  <circle cx="60" cy="60" r="52" fill="none" stroke="#6f4a86" strokeWidth="18" strokeDasharray="32.7 326.7" strokeDashoffset="-277.7" />
                  <circle cx="60" cy="60" r="52" fill="none" stroke="#5b6470" strokeWidth="18" strokeDasharray="16.3 326.7" strokeDashoffset="-310.4" />
                </g>
                <text x="60" y="57" textAnchor="middle" fill="#fff" fontSize="15" fontFamily="Georgia,serif">1.248</text>
                <text x="60" y="71" textAnchor="middle" fill="#8aa0bd" fontSize="7.5">Total</text>
              </svg>
              <div className="legend">
                <div className="li"><span className="sw" style={{ background: "#2f6b46" }} /> Saúde <b>42% (524)</b></div>
                <div className="li"><span className="sw" style={{ background: "#9a6b15" }} /> Infraestrutura <b>28% (349)</b></div>
                <div className="li"><span className="sw" style={{ background: "#2b5478" }} /> Educação <b>15% (187)</b></div>
                <div className="li"><span className="sw" style={{ background: "#6f4a86" }} /> Assistência Social <b>10% (125)</b></div>
                <div className="li"><span className="sw" style={{ background: "#5b6470" }} /> Outros <b>5% (63)</b></div>
              </div>
            </div>
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
