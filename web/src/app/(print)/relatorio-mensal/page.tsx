export default function RelatorioMensalPage() {
  return (
    <div className="print-page">
      <div className="watermark" />
      <div className="print-wrap">
        <div className="print-top">
          <div className="print-logo">
            <div className="mark">
              <svg className="ico" viewBox="0 0 24 24" style={{ width: 20, height: 20 }}>
                <path d="M3 21h18" />
                <path d="M5 21V10" />
                <path d="M19 21V10" />
                <path d="M4 10l8-6 8 6" />
                <path d="M9 21v-7" />
                <path d="M15 21v-7" />
              </svg>
            </div>
            <div>
              <div className="name">EVORA</div>
              <div className="sub">OVERSIGHT</div>
            </div>
          </div>
          <div className="print-tag">RELATÓRIO · CONFIDENCIAL</div>
        </div>

        <div className="print-kicker">Exemplo de relatório gerado pelo sistema</div>
        <div className="print-h1">Relatório Mensal de Atividades</div>
        <div className="print-sub">Gabinete da Vereadora Tatiane Costa — Câmara Municipal de Sorocaba/SP · Maio/2026</div>

        <div className="print-stats">
          <div className="print-stat"><b>1.248</b><span>Demandas recebidas</span></div>
          <div className="print-stat"><b>1.031</b><span>Demandas concluídas</span></div>
          <div className="print-stat"><b>18</b><span>Fiscalizações</span></div>
          <div className="print-stat"><b>83%</b><span>Taxa de resolução</span></div>
        </div>

        <div className="print-cols">
          <div className="print-card">
            <h3>1. Demandas por área</h3>
            <div className="print-bar-row"><div className="lb">Saúde</div><div className="tk"><div className="fl" style={{ width: "100%", background: "#2f6b46" }} /></div><div className="vv">524</div></div>
            <div className="print-bar-row"><div className="lb">Infraestrutura</div><div className="tk"><div className="fl" style={{ width: "67%", background: "#9a6b15" }} /></div><div className="vv">349</div></div>
            <div className="print-bar-row"><div className="lb">Educação</div><div className="tk"><div className="fl" style={{ width: "36%", background: "#2b5478" }} /></div><div className="vv">187</div></div>
            <div className="print-bar-row"><div className="lb">Assistência Social</div><div className="tk"><div className="fl" style={{ width: "24%", background: "#6f4a86" }} /></div><div className="vv">125</div></div>
            <div className="print-bar-row"><div className="lb">Outros</div><div className="tk"><div className="fl" style={{ width: "12%", background: "#8a8474" }} /></div><div className="vv">63</div></div>
          </div>
          <div className="print-card">
            <h3>2. Destaques do mês</h3>
            <ul className="print-list">
              <li>Resolução de <b>1.031 demandas</b>, 9% acima do mês anterior.</li>
              <li><b>18 fiscalizações</b> realizadas, com 214 evidências arquivadas.</li>
              <li><b>2 projetos de lei</b> protocolados e 1 indicação atendida.</li>
              <li>Tempo médio de primeira resposta: <b>2h14</b> (meta: 4h).</li>
            </ul>
          </div>
        </div>

        <div className="print-card">
          <h3>3. Pontos de atenção</h3>
          <ul className="print-list attn">
            <li><b className="crit">Crítico:</b> 30 demandas críticas aguardando resposta há mais de 15 dias.</li>
            <li><b className="alto">Alto:</b> contrato de transporte escolar com indícios de irregularidade — em apuração.</li>
            <li><b className="med">Médio:</b> ausência de protocolo formal de continuidade institucional.</li>
          </ul>
        </div>

        <div className="print-foot">
          <span>🔒 Documento confidencial — gerado automaticamente pela plataforma Évora Oversight · CNPJ 61.317.228/0001-02</span>
          <span>Maio/2026</span>
        </div>
      </div>
    </div>
  );
}
