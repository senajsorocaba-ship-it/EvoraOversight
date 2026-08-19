"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { useRouter, usePathname } from "next/navigation";
import { SidebarProvider, useSidebar } from "@/components/sidebar-context";
import { Sidebar } from "@/components/sidebar";

const REST_SEGUNDOS = 120;

// Telas "abertas por voz" (aprofundamento, item sigiloso etc.) — o timer de
// descanso fica desligado, igual ao data-rest-timer="off" das páginas
// originais, pra não interromper a demonstração de navegação por voz.
const ROTAS_SEM_TIMER = ["/visao-geral/aprofundamento", "/demandas/552", "/denuncias/sigilo"];

function Backdrop() {
  const { open, close } = useSidebar();
  return (
    <div
      className={"sb-backdrop" + (open ? " show" : "")}
      id="sb-backdrop"
      onClick={close}
    />
  );
}

function InactivityGuard() {
  const router = useRouter();
  const pathname = usePathname();
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const ativo = !ROTAS_SEM_TIMER.includes(pathname);

  useEffect(() => {
    if (!ativo) return;

    function reiniciar() {
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => {
        router.push("/modo-descanso");
      }, REST_SEGUNDOS * 1000);
    }

    const eventos = ["mousemove", "keydown", "touchstart", "click", "scroll"];
    eventos.forEach((ev) => document.addEventListener(ev, reiniciar, { passive: true }));
    reiniciar();

    return () => {
      if (timer.current) clearTimeout(timer.current);
      eventos.forEach((ev) => document.removeEventListener(ev, reiniciar));
    };
  }, [router, ativo]);

  return null;
}

export function DashboardShell({ children }: { children: ReactNode }) {
  return (
    <SidebarProvider>
      <div className="watermark" />
      <InactivityGuard />
      <div className="app">
        <Backdrop />
        <Sidebar />
        <div className="main">{children}</div>
      </div>
      <button className="vrx">🛟 VRX Support</button>
    </SidebarProvider>
  );
}
