"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { NAV_ITEMS } from "@/components/nav-items";
import { useSidebar } from "@/components/sidebar-context";

export function Sidebar() {
  const pathname = usePathname();
  const { open, close } = useSidebar();

  return (
    <aside className={"sidebar" + (open ? " open" : "")} id="sidebar">
      <div className="sb-logo">
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

      <nav className="sb-nav">
        {NAV_ITEMS.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            onClick={close}
            className={"sb-item" + (pathname === item.href ? " active" : "")}
          >
            {item.icon} {item.label}
          </Link>
        ))}
      </nav>

      <div className="sb-security">
        <div className="t">🔒 Segurança Institucional</div>
        <div className="l">
          Nível: <b>ALTO</b>
        </div>
        <div className="l">Último backup: hoje, 08:15</div>
      </div>
    </aside>
  );
}
