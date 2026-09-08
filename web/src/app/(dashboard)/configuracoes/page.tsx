import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";
import { EnrolamentoFacial } from "@/components/enrolamento-facial";

export default function ConfiguracoesPage() {
  return (
    <>
      <Topbar title="Configurações" subtitle="Usuários, segurança e infraestrutura" />

      <main className="content">
        <div className="cfg-grid">
          <EnrolamentoFacial />
          <div className="cfg-card">
            <div className="cic" style={{ background: "rgba(43,84,120,.3)", color: "#8fbfe0" }}>
              <svg className="ico" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3" /></svg>
            </div>
            <h4>Usuários e Perfis</h4>
            <p>Gabinete, assessores e níveis de acesso (Gestor, Operador, Leitura). 6 usuários ativos.</p>
          </div>
          <div className="cfg-card">
            <div className="cic" style={{ background: "rgba(154,107,21,.3)", color: "#e0a53a" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M12 2 4 5v6c0 5 3.4 9 8 11 4.6-2 8-6 8-11V5z" /></svg>
            </div>
            <h4>Segurança (Aegis)</h4>
            <p>Controle de acesso, 2 fatores e registro de tudo. Inventário de senhas e cofre digital.</p>
          </div>
          <div className="cfg-card">
            <div className="cic" style={{ background: "rgba(157,53,53,.3)", color: "#e07a7a" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" /></svg>
            </div>
            <h4>Defesa Cibernética (Sisec)</h4>
            <p>Monitoramento de tentativas de acesso externo e blindagem contra invasão.</p>
          </div>
          <div className="cfg-card">
            <div className="cic" style={{ background: "rgba(111,74,134,.3)", color: "#b78fd6" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /></svg>
            </div>
            <h4>Continuidade (Sigma)</h4>
            <p>Guardiões e protocolo de sucessão para ausência, incapacidade ou emergência.</p>
          </div>
          <div className="cfg-card">
            <div className="cic" style={{ background: "rgba(47,107,70,.3)", color: "#5fae7e" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
            </div>
            <h4>Acervo Jurídico (Veritas)</h4>
            <p>Legislação municipal, estadual e federal disponível aos agentes.</p>
          </div>
          <div className="cfg-card">
            <div className="cic" style={{ background: "rgba(43,84,120,.3)", color: "#8fbfe0" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" /></svg>
            </div>
            <h4>Integrações &amp; LGPD</h4>
            <p>WhatsApp, e-mail, portal do cidadão. Consentimento e finalidade por dado.</p>
          </div>
          <div className="cfg-card">
            <div className="cic" style={{ background: "rgba(154,107,21,.3)", color: "#e0a53a" }}>
              <svg className="ico" viewBox="0 0 24 24"><path d="M12 2 4 5v6c0 5 3.4 9 8 11 4.6-2 8-6 8-11V5z" /></svg>
            </div>
            <h4>Auditoria Soberana (AAS)</h4>
            <p>Registra tudo, de todos — reporta só à autoridade. Trilha imutável: ninguém desliga, nem o suporte.</p>
          </div>
          <div className="cfg-card">
            <div className="cic" style={{ background: "rgba(111,74,134,.3)", color: "#b78fd6" }}>
              <svg className="ico" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></svg>
            </div>
            <h4>Mentor da Autoridade (AMA)</h4>
            <p>Conselheiro pessoal e privado da autoridade. Perfil em cofre cifrado (SigmaOne); acesso exclusivo.</p>
          </div>
        </div>
      </main>
      <FooterLegal />
    </>
  );
}
