import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function AtendimentosPage() {
  return (
    <>
      <Topbar title="Atendimentos" subtitle="Canais e histórico de atendimento ao cidadão" />

      <main className="content">
        <div className="kpis" style={{ gridTemplateColumns: "repeat(4,1fr)" }}>
          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                </svg>
              </div>
              <div className="lbl">Atendimentos no mês</div>
            </div>
            <div className="num">1.486</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic green">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
                </svg>
              </div>
              <div className="lbl">Via WhatsApp</div>
            </div>
            <div className="num">58%</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic amber">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                </svg>
              </div>
              <div className="lbl">Presencial</div>
            </div>
            <div className="num">27%</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic purple">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.68 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.32 1.85.55 2.81.68A2 2 0 0 1 22 16.92z" />
                </svg>
              </div>
              <div className="lbl">Telefone</div>
            </div>
            <div className="num">15%</div>
          </div>
        </div>

        <div className="grid2">
          <div className="card bars">
            <h3>Atendimentos por canal</h3>
            <div className="brow"><div className="blbl"><span>WhatsApp</span><b>58%</b></div><div className="btrack"><div className="bfill" style={{ width: "58%", background: "#2fb0a8" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Presencial</span><b>27%</b></div><div className="btrack"><div className="bfill" style={{ width: "27%", background: "#5fae7e" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Telefone</span><b>15%</b></div><div className="btrack"><div className="bfill" style={{ width: "15%", background: "#6f4a86" }} /></div></div>
            <div className="brow"><div className="blbl"><span>E-mail / Site</span><b>9%</b></div><div className="btrack"><div className="bfill" style={{ width: "9%", background: "#2b5478" }} /></div></div>
          </div>
          <div className="card">
            <h3>Tempo médio de primeira resposta</h3>
            <div style={{ fontFamily: "Georgia,serif", fontSize: 34, color: "#fff" }}>2h 14min</div>
            <div style={{ fontSize: 12, color: "var(--mut)", marginTop: 4 }}>média no mês · meta: 4h</div>
            <div className="badge baixo" style={{ marginTop: 10 }}>38% abaixo da meta</div>
          </div>
        </div>

        <div className="card">
          <h3>Atendimentos de hoje</h3>
          <div className="tablewrap">
            <table>
              <thead><tr><th>Hora</th><th>Cidadão</th><th>Canal</th><th>Assunto</th><th>Responsável</th><th>Status</th></tr></thead>
              <tbody>
                <tr><td>09:42</td><td>Maria S. Lima</td><td><span className="chip">WhatsApp</span></td><td>Falta de médico no posto</td><td>Júlia (assessora)</td><td><span className="badge resolvido">Resolvido</span></td></tr>
                <tr><td>09:31</td><td>João P. Alves</td><td><span className="chip">Presencial</span></td><td>Buraco na via</td><td>Marcos (assessor)</td><td><span className="badge encaminhada">Encaminhado</span></td></tr>
                <tr><td>09:15</td><td>Ana C. Rocha</td><td><span className="chip">WhatsApp</span></td><td>Vaga em creche</td><td>Júlia (assessora)</td><td><span className="badge aguardando">Aguardando</span></td></tr>
                <tr><td>08:58</td><td>Carlos M.</td><td><span className="chip">Telefone</span></td><td>Iluminação</td><td>Bot Verix → Júlia</td><td><span className="badge andamento">Em andamento</span></td></tr>
                <tr><td>08:40</td><td>Beatriz N.</td><td><span className="chip">WhatsApp</span></td><td>Transporte escolar</td><td>Marcos (assessor)</td><td><span className="badge resolvido">Resolvido</span></td></tr>
                <tr><td>08:22</td><td>Rafael T.</td><td><span className="chip">Presencial</span></td><td>Coleta de lixo</td><td>Júlia (assessora)</td><td><span className="badge andamento">Em andamento</span></td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
