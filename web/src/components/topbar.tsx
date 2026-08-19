"use client";

import { useRouter } from "next/navigation";
import { useSidebar } from "@/components/sidebar-context";
import { createClient } from "@/lib/supabase/client";

export function Topbar({
  title,
  subtitle,
}: {
  title: string;
  subtitle: string;
}) {
  const { toggle } = useSidebar();
  const router = useRouter();

  async function sair() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  return (
    <header className="topbar">
      <button className="hamb" id="hamb" onClick={toggle}>
        ☰
      </button>
      <div className="tb-title">
        <h1>{title}</h1>
        <p>{subtitle}</p>
      </div>
      <div className="tb-right">
        <div className="pill bia">
          <span className="dot" /> B <span className="lbl-txt">Bia · ouvindo</span>
        </div>
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
