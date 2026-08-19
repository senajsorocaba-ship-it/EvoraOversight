import Link from "next/link";
import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function VisaoGeralPage() {
  return (
    <>
      <Topbar
        title="Painel Executivo do Gabinete"
        subtitle="Vereadora Tatiane Costa · Período: últimos 30 dias"
      />

      <main className="content">
        <div className="kpis">
          <Link className="kpi" href="/visao-geral/aprofundamento">
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
          </Link>

          <div className="kpi">
            <div className="row">
              <div className="ic green">
                <svg className="ico" viewBox="0 0 24 24">
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              </div>
              <div className="lbl">Demandas concluídas</div>
            </div>
            <div className="num">1.031</div>
            <div className="delta up">+9% vs. período anterior</div>
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
            <div className="delta up">+5% vs. período anterior</div>
          </div>

          <div className="kpi">
            <div className="row">
              <div className="ic red">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                  <line x1="12" y1="9" x2="12" y2="13" />
                  <line x1="12" y1="17" x2="12.01" y2="17" />
                </svg>
              </div>
              <div className="lbl">Críticas pendentes</div>
            </div>
            <div className="num">30</div>
            <div className="delta down">-3% vs. período anterior</div>
          </div>

          <div className="kpi">
            <div className="row">
              <div className="ic purple">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M12 2 4 5v6c0 5 3.4 9 8 11 4.6-2 8-6 8-11V5z" />
                </svg>
              </div>
              <div className="lbl">Fiscalizações realizadas</div>
            </div>
            <div className="num">18</div>
          </div>

          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                  <polyline points="14 2 14 8 20 8" />
                </svg>
              </div>
              <div className="lbl">Requerimentos protocolados</div>
            </div>
            <div className="num">42</div>
          </div>

          <div className="kpi">
            <div className="row">
              <div className="ic green">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                  <polyline points="14 2 14 8 20 8" />
                </svg>
              </div>
              <div className="lbl">Projetos de lei em tramitação</div>
            </div>
            <div className="num">11</div>
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

        <div className="grid3">
          <div className="card">
            <h3>Demandas por Área</h3>
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

          <div className="card">
            <h3>Mapa de Criticidade</h3>
            <div className="tablewrap">
              <table style={{ minWidth: 280 }}>
                <thead>
                  <tr><th>Área</th><th>Baixo</th><th>Médio</th><th>Alto</th><th>Crítico</th></tr>
                </thead>
                <tbody>
                  <tr><td>Saúde</td><td>12</td><td>31</td><td>18</td><td>4</td></tr>
                  <tr><td>Educação</td><td>8</td><td>12</td><td>4</td><td>0</td></tr>
                  <tr><td>Obras</td><td>5</td><td>19</td><td>11</td><td>2</td></tr>
                  <tr><td>Transporte</td><td>3</td><td>7</td><td>5</td><td>1</td></tr>
                </tbody>
              </table>
            </div>
          </div>

          <div className="card">
            <h3>Fiscalizações Prioritárias</h3>
            <div className="listline"><span className="dot" style={{ background: "#e07a7a" }} /><div className="tt">Unidade Básica de Saúde Central<small>Criticidade: <b style={{ color: "#e07a7a" }}>CRÍTICA</b></small></div></div>
            <div className="listline"><span className="dot" style={{ background: "#e07a7a" }} /><div className="tt">Contrato de Transporte Escolar<small>Criticidade: <b style={{ color: "#e07a7a" }}>CRÍTICA</b></small></div></div>
            <div className="listline"><span className="dot" style={{ background: "#e0a53a" }} /><div className="tt">Obra da Avenida Principal<small>Criticidade: <b style={{ color: "#e0a53a" }}>ALTA</b></small></div></div>
            <div className="listline"><span className="dot" style={{ background: "#e0a53a" }} /><div className="tt">Creche Municipal Setor Norte<small>Criticidade: <b style={{ color: "#e0a53a" }}>ALTA</b></small></div></div>
            <div className="listline"><span className="dot" style={{ background: "#9fc4e6" }} /><div className="tt">Iluminação Pública – Centro<small>Criticidade: <b style={{ color: "#9fc4e6" }}>MÉDIA</b></small></div></div>
          </div>
        </div>

        <div className="grid3">
          <div className="card">
            <h3>Demandas sem Movimentação</h3>
            <div className="tablewrap">
              <table style={{ minWidth: 260 }}>
                <thead><tr><th>Assunto</th><th>Dias sem atualização</th></tr></thead>
                <tbody>
                  <tr><td>Saúde</td><td><span className="badge critica">18</span></td></tr>
                  <tr><td>Transporte</td><td><span className="badge alta">14</span></td></tr>
                  <tr><td>Obras</td><td><span className="badge alta">11</span></td></tr>
                  <tr><td>Educação</td><td><span className="badge media">8</span></td></tr>
                </tbody>
              </table>
            </div>
          </div>

          <div className="card bars">
            <h3>Indicador de Eficiência do Gabinete</h3>
            <div className="brow"><div className="blbl"><span>Atendimento ao Cidadão</span><b>91%</b></div><div className="btrack"><div className="bfill" style={{ width: "91%", background: "#5fae7e" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Fiscalização</span><b>84%</b></div><div className="btrack"><div className="bfill" style={{ width: "84%", background: "#2b5478" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Transparência</span><b>76%</b></div><div className="btrack"><div className="bfill" style={{ width: "76%", background: "#6f4a86" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Controle Interno</span><b>68%</b></div><div className="btrack"><div className="bfill" style={{ width: "68%", background: "#e0a53a" }} /></div></div>
            <div className="brow"><div className="blbl"><span>Segurança Institucional</span><b>55%</b></div><div className="btrack"><div className="bfill" style={{ width: "55%", background: "#e07a7a" }} /></div></div>
          </div>

          <div className="card">
            <h3>Alertas Estratégicos</h3>
            <div className="alert warn">⚠ Não existe inventário formal de senhas institucionais.</div>
            <div className="alert warn">⚠ Dependência elevada de dois assessores-chave.</div>
            <div className="alert warn">⚠ Ausência de protocolo de continuidade institucional.</div>
            <div className="alert warn">⚠ 30 demandas críticas aguardando resposta.</div>
            <div className="alert ok">✓ Nenhum prazo legislativo vencido no período.</div>
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
