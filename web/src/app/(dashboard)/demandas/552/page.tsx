import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function Demanda552Page() {
  return (
    <>
      <Topbar
        title="Demanda 552 — navegação por voz (A.T.)"
        subtitle="Regras 03 e 04 · paridade total: voz, texto ou clique · persistência de modalidade"
      />

      <main className="content">
        <div className="voice-banner">
          🎤 Sessão por voz ativa — comandos reconhecidos: &quot;Bia, abra a aba Demandas&quot; → &quot;quero ver a demanda 552&quot; → &quot;amplie&quot; (A.T.)
          <span className="ok">tela cheia · dashboard preservado atrás</span>
        </div>
        <div className="card">
          <div className="dd-sub">Demanda · aberta por comando de voz</div>
          <div className="dd-title">#2026-0552 — Falta de transporte adaptado para cadeirante</div>
          <div className="dd-badges">
            <span className="chip">Saúde/Acessibilidade</span>
            <span className="chip">WhatsApp</span>
            <span className="badge andamento">Em andamento</span>
          </div>
          <div className="grid2" style={{ marginTop: 16 }}>
            <div>
              <div className="mini-h">Dados da demanda</div>
              <ul className="dl">
                <li><b>Cidadã:</b> Helena M. Castro · Jd. Santa Rosália</li>
                <li><b>Recebida:</b> 21/05 · <b>Prazo:</b> em 4 dias</li>
                <li><b>Responsável:</b> Júlia (assessora) · ADC</li>
                <li><b>Órgão acionado:</b> Sec. de Mobilidade (Ofício 461/2026)</li>
              </ul>
              <div className="mini-h" style={{ marginTop: 18 }}>Pesquisar nesta demanda — por voz</div>
              <div className="mic-row">
                <button className="mic-btn">🎤</button> &quot;Bia, o que a Secretaria respondeu?&quot; · &quot;há casos parecidos no bairro?&quot;
              </div>
              <div className="bia-answer">
                A Secretaria respondeu em 09/06: veículo adaptado previsto para a linha 27 em 30 dias. Há 3 demandas semelhantes no bairro — posso consolidá-las num requerimento.
                <span className="src">Fontes: ADC · ofício 461/2026 · base de demandas</span>
              </div>
            </div>
            <div>
              <div className="mini-h">Histórico</div>
              <div className="timeline">
                <div className="tl-item"><b>21/05</b>Recebida via WhatsApp (protocolo automático)</div>
                <div className="tl-item"><b>22/05</b>Triagem ADC — criticidade ALTA</div>
                <div className="tl-item"><b>23/05</b>Ofício 461/2026 enviado à Sec. de Mobilidade</div>
                <div className="tl-item"><b>09/06</b>Resposta da Secretaria recebida e anexada</div>
                <div className="tl-item"><b>hoje</b>Aberta por voz pela usuária — consulta em curso</div>
              </div>
            </div>
          </div>
          <div className="cmdhint">
            Comandos de janela disponíveis: <code>&quot;dividir&quot;</code> → lado a lado · <code>&quot;minimizar&quot;</code> → vira botão · <code>&quot;voltar&quot;</code> → dashboard · <code>&quot;imprima o histórico&quot;</code> (R06)
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
