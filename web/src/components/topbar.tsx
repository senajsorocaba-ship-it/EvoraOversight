"use client";

import { useRouter } from "next/navigation";
import { useSidebar } from "@/components/sidebar-context";
import { useBiaVoz } from "@/components/bia-voz-context";
import { createClient } from "@/lib/supabase/client";
import { destravar } from "@/lib/trava-tela";

export function Topbar({
  title,
  subtitle,
}: {
  title: string;
  subtitle: string;
}) {
  const { toggle } = useSidebar();
  const router = useRouter();
  const bia = useBiaVoz();

  async function sair() {
    const supabase = createClient();
    await supabase.auth.signOut();
    destravar();
    router.push("/login");
    router.refresh();
  }

  function alternarBia() {
    if (bia.ligada) bia.desligar();
    else bia.ligar();
  }

  const rotuloBia = bia.processando
    ? "Bia · pensando…"
    : bia.ouvindo
    ? "Bia · ouvindo"
    : bia.ligada
    ? "Bia · reconectando…"
    : "Bia · desligada";

  return (
    <header className="topbar">
      <button className="hamb" id="hamb" onClick={toggle}>
        ☰
      </button>
      <div className="tb-title">
        <h1>{title}</h1>
        <p>{subtitle}</p>
        {(bia.transcricaoAoVivo || bia.ultimoComando || bia.respostaFalada || bia.erro) && (
          <p className="bia-transcricao" style={{ fontSize: 12, color: "var(--mut)", marginTop: 2 }}>
            {bia.erro
              ? `⚠ ${bia.erro}`
              : bia.transcricaoAoVivo
              ? `… ${bia.transcricaoAoVivo}`
              : bia.respostaFalada
              ? `Bia: ${bia.respostaFalada}`
              : bia.ultimoComando
              ? `Entendi: "${bia.ultimoComando}"`
              : null}
          </p>
        )}
      </div>
      <div className="tb-right">
        <button
          type="button"
          className={"pill bia" + (bia.ouvindo ? " ativo" : "")}
          onClick={alternarBia}
          title={bia.suportado ? "Clique pra ligar/desligar a escuta da Bia" : "Não suportado neste navegador"}
          suppressHydrationWarning
          style={{ border: "none", cursor: "pointer" }}
        >
          <span className="dot" /> B <span className="lbl-txt">{rotuloBia}</span>
        </button>
        <div className="pill nil">
          N <span className="lbl-txt">Nil · 🔒 sob alçada</span>
        </div>
        <div className="bell">
          ⚠<span className="badge-n badge">3</span>
        </div>
        <button
          className="user"
          onClick={sair}
          title="Sair"
          style={{ background: "none", border: "none", cursor: "pointer", padding: 0 }}
        >
          <div className="av">G</div>
          <div className="meta">
            <div className="n">Gabinete</div>
            <div className="r">Acesso: Gestor · Sair</div>
          </div>
        </button>
      </div>
    </header>
  );
}
