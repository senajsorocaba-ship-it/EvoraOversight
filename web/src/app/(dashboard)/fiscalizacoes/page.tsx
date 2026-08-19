import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function FiscalizacoesPage() {
  return (
    <>
      <Topbar title="Fiscalizações" subtitle="Fiscalização do Executivo e registro de evidências" />

      <main className="content">
        <div className="kpis" style={{ gridTemplateColumns: "repeat(4,1fr)" }}>
          <div className="kpi">
            <div className="row">
              <div className="ic purple">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M12 2 4 5v6c0 5 3.4 9 8 11 4.6-2 8-6 8-11V5z" />
                </svg>
              </div>
              <div className="lbl">Realizadas (ano)</div>
            </div>
            <div className="num">18</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic amber">
                <svg className="ico" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="9" />
                  <polyline points="12 7 12 12 16 14" />
                </svg>
              </div>
              <div className="lbl">Em curso</div>
            </div>
            <div className="num">5</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic red">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                </svg>
              </div>
              <div className="lbl">Pendências críticas</div>
            </div>
            <div className="num">6</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
                </svg>
              </div>
              <div className="lbl">Evidências arquivadas</div>
            </div>
            <div className="num">214</div>
          </div>
        </div>

        <div className="card">
          <h3>Fiscalizações — registro e evidências</h3>
          <div className="tablewrap">
            <table>
              <thead><tr><th>Objeto</th><th>Órgão</th><th>Tipo</th><th>Data</th><th>Evidências</th><th>Criticidade</th><th>Status</th></tr></thead>
              <tbody>
                <tr><td>Unidade Básica de Saúde Central</td><td>Sec. Saúde</td><td>Visita técnica</td><td>02/06</td><td><span className="chip">12 fotos</span></td><td><span className="badge critica">CRÍTICA</span></td><td><span className="badge concluida">Relatório emitido</span></td></tr>
                <tr><td>Contrato Transporte Escolar</td><td>Sec. Educação</td><td>Análise contratual</td><td>28/05</td><td><span className="chip">8 docs</span></td><td><span className="badge critica">CRÍTICA</span></td><td><span className="badge apuracao">Em apuração</span></td></tr>
                <tr><td>Obra da Avenida Principal</td><td>Sec. Obras</td><td>Vistoria in loco</td><td>21/05</td><td><span className="chip">23 fotos</span></td><td><span className="badge alta">ALTA</span></td><td><span className="badge andamento">Notificado</span></td></tr>
                <tr><td>Creche Setor Norte</td><td>Sec. Educação</td><td>Visita técnica</td><td>14/05</td><td><span className="chip">9 fotos</span></td><td><span className="badge alta">ALTA</span></td><td><span className="badge andamento">Acompanhamento</span></td></tr>
                <tr><td>Iluminação Pública – Centro</td><td>Sec. Infra</td><td>Inspeção</td><td>07/05</td><td><span className="chip">5 fotos</span></td><td><span className="badge media">MÉDIA</span></td><td><span className="badge concluida">Concluída</span></td></tr>
              </tbody>
            </table>
          </div>
          <div className="modal-note" style={{ marginTop: 14 }}>Cada fiscalização guarda evidências (fotos, documentos, áudios) com data, autor e geolocalização — prontas para virar requerimento, denúncia ou matéria.</div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
