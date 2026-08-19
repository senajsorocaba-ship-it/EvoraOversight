import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function AgendaPage() {
  return (
    <>
      <Topbar title="Agenda" subtitle="Compromissos, sessões e vistorias" />

      <main className="content">
        <div className="kpis" style={{ gridTemplateColumns: "repeat(4,1fr)" }}>
          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <rect x="3" y="4" width="18" height="18" rx="2" />
                  <line x1="16" y1="2" x2="16" y2="6" />
                  <line x1="8" y1="2" x2="8" y2="6" />
                </svg>
              </div>
              <div className="lbl">Compromissos na semana</div>
            </div>
            <div className="num">23</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic amber">
                <svg className="ico" viewBox="0 0 24 24"><path d="M12 2 4 5v6c0 5 3.4 9 8 11 4.6-2 8-6 8-11V5z" /></svg>
              </div>
              <div className="lbl">Vistorias agendadas</div>
            </div>
            <div className="num">4</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic purple">
                <svg className="ico" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
              </div>
              <div className="lbl">Sessões / comissões</div>
            </div>
            <div className="num">5</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic green">
                <svg className="ico" viewBox="0 0 24 24"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /></svg>
              </div>
              <div className="lbl">Atendimentos marcados</div>
            </div>
            <div className="num">9</div>
          </div>
        </div>

        <div className="card">
          <h3>Semana de 09 a 13 de junho</h3>
          <div className="agenda-week">
            <div className="aday"><h4>Seg 09</h4><div className="aevt"><b>09:00</b>Reunião de equipe</div><div className="aevt"><b>14:00</b>Atendimento ao cidadão</div></div>
            <div className="aday"><h4>Ter 10</h4><div className="aevt"><b>10:00</b>Comissão de Saúde</div><div className="aevt"><b>16:00</b>Visita – UBS Central</div></div>
            <div className="aday"><h4>Qua 11</h4><div className="aevt"><b>09:30</b>Sessão plenária</div></div>
            <div className="aday"><h4>Qui 12</h4><div className="aevt"><b>11:00</b>Vistoria de obra</div><div className="aevt"><b>15:00</b>Imprensa</div></div>
            <div className="aday"><h4>Sex 13</h4><div className="aevt"><b>10:00</b>Audiência pública</div><div className="aevt"><b>13:00</b>Gabinete – despachos</div></div>
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
