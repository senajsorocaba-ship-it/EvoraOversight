import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";
import { ClickableRow } from "@/components/clickable-row";

export default function DenunciasPage() {
  return (
    <>
      <Topbar title="Denúncias" subtitle="Canal de denúncias e apuração" />

      <main className="content">
        <div className="kpis" style={{ gridTemplateColumns: "repeat(4,1fr)" }}>
          <div className="kpi">
            <div className="row">
              <div className="ic red">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                </svg>
              </div>
              <div className="lbl">Recebidas</div>
            </div>
            <div className="num">67</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic amber">
                <svg className="ico" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="9" />
                  <polyline points="12 7 12 12 16 14" />
                </svg>
              </div>
              <div className="lbl">Em apuração</div>
            </div>
            <div className="num">19</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic green">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M12 2 4 5v6c0 5 3.4 9 8 11 4.6-2 8-6 8-11V5z" />
                </svg>
              </div>
              <div className="lbl">Procedentes</div>
            </div>
            <div className="num">23</div>
          </div>
          <div className="kpi">
            <div className="row">
              <div className="ic blue">
                <svg className="ico" viewBox="0 0 24 24">
                  <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
                </svg>
              </div>
              <div className="lbl">Arquivadas</div>
            </div>
            <div className="num">25</div>
          </div>
        </div>

        <div className="card">
          <h3>Canal de denúncias — registro e sigilo</h3>
          <div className="tablewrap">
            <table>
              <thead><tr><th>Protocolo</th><th>Tema</th><th>Origem</th><th>Data</th><th>Sigilo</th><th>Status</th></tr></thead>
              <tbody>
                <ClickableRow href="/denuncias/sigilo">
                  <td>#DN-219</td><td>Possível sobrepreço em obra</td><td>Cidadão (anônimo)</td><td>04/06</td><td><span className="badge sigiloso">Sigiloso</span></td><td><span className="badge apuracao">Em apuração</span></td>
                </ClickableRow>
                <tr><td>#DN-217</td><td>Atraso reiterado de merenda</td><td>Servidor</td><td>02/06</td><td><span className="badge reservado">Reservado</span></td><td><span className="badge procedente">Procedente</span></td></tr>
                <ClickableRow href="/denuncias/sigilo">
                  <td>#DN-214</td><td>Irregularidade em licitação</td><td>Cidadão</td><td>29/05</td><td><span className="badge sigiloso">Sigiloso</span></td><td><span className="badge apuracao">Em apuração</span></td>
                </ClickableRow>
                <ClickableRow href="/denuncias/sigilo">
                  <td>#DN-210</td><td>Mau uso de veículo público</td><td>Cidadão (anônimo)</td><td>22/05</td><td><span className="badge sigiloso">Sigiloso</span></td><td><span className="chip">Arquivada</span></td>
                </ClickableRow>
                <tr><td>#DN-205</td><td>Falta de acessibilidade</td><td>Cidadão</td><td>15/05</td><td><span className="badge publico">Público</span></td><td><span className="badge procedente">Procedente</span></td></tr>
              </tbody>
            </table>
          </div>
          <div className="modal-note" style={{ marginTop: 14 }}>Denúncias entram por canal sigiloso, recebem protocolo e trilha de apuração — protegendo o denunciante e a autoridade.</div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
