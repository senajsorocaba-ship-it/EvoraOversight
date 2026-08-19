"use client";

import { useSidebar } from "@/components/sidebar-context";

export function Topbar({
  title,
  subtitle,
}: {
  title: string;
  subtitle: string;
}) {
  const { toggle } = useSidebar();

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
        <div className="user">
          <div className="av">G</div>
          <div className="meta">
            <div className="n">Gabinete</div>
            <div className="r">Acesso: Gestor</div>
          </div>
        </div>
      </div>
    </header>
  );
}
