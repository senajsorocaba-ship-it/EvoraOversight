import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";

export default function DocumentosPage() {
  return (
    <>
      <Topbar title="Documentos" subtitle="Acervo documental do mandato" />

      <main className="content">
        <div className="folders">
          <div className="folder">
            <div className="fic" style={{ background: "rgba(43,84,120,.3)", color: "#8fbfe0" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" /></svg>
            </div>
            <div className="ft">Ofícios</div><div className="fn">312 arquivos</div>
          </div>
          <div className="folder">
            <div className="fic" style={{ background: "rgba(111,74,134,.3)", color: "#b78fd6" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" /></svg>
            </div>
            <div className="ft">Requerimentos</div><div className="fn">148 arquivos</div>
          </div>
          <div className="folder">
            <div className="fic" style={{ background: "rgba(47,107,70,.3)", color: "#5fae7e" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" /></svg>
            </div>
            <div className="ft">Contratos</div><div className="fn">96 arquivos</div>
          </div>
          <div className="folder">
            <div className="fic" style={{ background: "rgba(154,107,21,.3)", color: "#e0a53a" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" /></svg>
            </div>
            <div className="ft">Evidências</div><div className="fn">214 arquivos</div>
          </div>
          <div className="folder">
            <div className="fic" style={{ background: "rgba(47,107,70,.3)", color: "#5fae7e" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" /></svg>
            </div>
            <div className="ft">Projetos de Lei</div><div className="fn">54 arquivos</div>
          </div>
          <div className="folder">
            <div className="fic" style={{ background: "rgba(157,53,53,.3)", color: "#e07a7a" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" /></svg>
            </div>
            <div className="ft">Confidenciais</div><div className="fn">37 arquivos</div>
          </div>
        </div>

        <div className="card">
          <h3>Documentos recentes</h3>
          <div className="tablewrap">
            <table>
              <thead><tr><th>Nome</th><th>Tipo</th><th>Arquivo</th><th>Data</th><th>Acesso</th></tr></thead>
              <tbody>
                <tr><td>Ofício 482/2026 – Sec. Saúde</td><td>Ofício</td><td>PDF · 220 KB</td><td>04/06</td><td><span className="badge gabinete">Gabinete</span></td></tr>
                <tr><td>Contrato Transporte Escolar (íntegra)</td><td>Contrato</td><td>PDF · 1,8 MB</td><td>28/05</td><td><span className="badge restrito">Restrito</span></td></tr>
                <tr><td>Relatório de Fiscalização – UBS Central</td><td>Relatório</td><td>PDF · 4,2 MB</td><td>02/06</td><td><span className="badge gabinete">Gabinete</span></td></tr>
                <tr><td>Inventário de Acessos (Aegis)</td><td>Segurança</td><td>Cofre · cifrado</td><td>01/06</td><td><span className="badge confidencial">Confidencial</span></td></tr>
                <tr><td>PL 045/2026 – Saúde da Mulher</td><td>Projeto</td><td>DOCX · 96 KB</td><td>03/06</td><td><span className="badge publico">Público</span></td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
