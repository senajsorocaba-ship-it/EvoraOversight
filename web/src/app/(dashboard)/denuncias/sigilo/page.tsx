import Link from "next/link";
import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function DenunciaSigilosaPage() {
  return (
    <>
      <Topbar
        title="Denúncias — abertura de item sigiloso por voz"
        subtitle="Confirmação falada obrigatória antes de expor conteúdo sigiloso"
      />

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

        <div
          className="overlay show"
          style={{ position: "static", background: "none", padding: 0, display: "block", marginBottom: 18 }}
        >
          <div className="modal" style={{ maxWidth: 600, margin: "0 auto" }}>
            <div className="modal-h">
              <div>
                <span className="mk">Comando de voz recebido</span>
                <h2>&quot;Bia, abra a denúncia DN-214&quot;</h2>
              </div>
              <Link href="/denuncias">
                <button className="x">×</button>
              </Link>
            </div>
            <div className="modal-b">
              <div className="sig-warn">⚠ Conteúdo classificado como <b>SIGILOSO</b> — confirmação falada obrigatória (Regra 04)</div>
              <div className="sig-q">
                &quot;Confirma abrir a denúncia <b>DN-214 — Irregularidade em licitação</b>, classificada como <b>sigilosa</b>? Há outras pessoas no ambiente?&quot;
                <span className="meta">Alçada verificada ✓ · biometria de voz confirmada ✓ · modalidade: voz (persistente)</span>
              </div>
              <div className="sig-btns">
                <button className="primary">🎤 &quot;Confirmo&quot; — abrir</button>
                <Link href="/denuncias"><button className="ghost">🎤 &quot;Cancelar&quot;</button></Link>
                <button className="ghost">&quot;modo texto&quot; — abrir em silêncio</button>
              </div>
              <div className="modal-note" style={{ marginTop: 12 }}>Em modo silencioso (clique/texto) o sistema não vocaliza conteúdo sigiloso. Este acesso, confirmado ou cancelado, é registrado na AAS.</div>
              <div className="modal-note">🔒 Denúncias: protocolo, sigilo do denunciante e trilha de apuração — Regras 03 · 04 · 07.</div>
            </div>
          </div>
        </div>

        <div className="card">
          <h3>Canal de denúncias — registro e sigilo</h3>
          <div className="tablewrap">
            <table>
              <thead><tr><th>Protocolo</th><th>Tema</th><th>Origem</th><th>Data</th><th>Sigilo</th><th>Status</th></tr></thead>
              <tbody>
                <tr><td>#DN-219</td><td>Possível sobrepreço em obra</td><td>Cidadão (anônimo)</td><td>04/06</td><td><span className="badge sigiloso">Sigiloso</span></td><td><span className="badge apuracao">Em apuração</span></td></tr>
                <tr><td>#DN-217</td><td>Atraso reiterado de merenda</td><td>Servidor</td><td>02/06</td><td><span className="badge reservado">Reservado</span></td><td><span className="badge procedente">Procedente</span></td></tr>
                <tr style={{ background: "rgba(181,152,90,.08)" }}><td>#DN-214</td><td>Irregularidade em licitação</td><td>Cidadão</td><td>29/05</td><td><span className="badge sigiloso">Sigiloso</span></td><td><span className="badge apuracao">Em apuração</span></td></tr>
                <tr><td>#DN-210</td><td>Mau uso de veículo público</td><td>Cidadão (anônimo)</td><td>22/05</td><td><span className="badge sigiloso">Sigiloso</span></td><td><span className="chip">Arquivada</span></td></tr>
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
