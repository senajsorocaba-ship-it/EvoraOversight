"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { useRouter, usePathname } from "next/navigation";
import { SidebarProvider, useSidebar } from "@/components/sidebar-context";
import { BiaVozProvider, useBiaVoz } from "@/components/bia-voz-context";
import { Sidebar } from "@/components/sidebar";
import { VigiaPresenca } from "@/components/vigia-presenca";
import { CHAVE_TRAVADO, travar } from "@/lib/trava-tela";

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
  // Bug real encontrado: o modo descanso vivia fora do grupo de rotas do
  // dashboard, então disparar aqui desmontava o BiaVozProvider inteiro —
  // matando o reconhecimento em andamento sem nenhum aviso. Falar com a
  // Bia é presença, mesmo sem mexer o mouse — então o timer não deve
  // disparar (nem continuar contando) enquanto ela estiver ligada.
  const bia = useBiaVoz();
  const ativo = !ROTAS_SEM_TIMER.includes(pathname) && !bia.ligada;

  useEffect(() => {
    if (!ativo) return;

    function reiniciar() {
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => {
        travar(router);
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

// Fecha a brecha achada na exploração: o bloqueio era só estado de React,
// então um F5 (ou digitar a URL do dashboard direto) destravava sozinho.
// Se a flag estiver marcada e a rota não for /modo-descanso, redireciona
// pra lá assim que este componente monta — antes de qualquer conteúdo do
// dashboard aparecer na tela.
function TravaGuard() {
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (pathname === "/modo-descanso") return;
    try {
      if (window.sessionStorage.getItem(CHAVE_TRAVADO) === "1") {
        router.replace("/modo-descanso");
      }
    } catch (e) {
      console.error("[TravaGuard] não consegui ler sessionStorage:", e);
    }
  }, [pathname, router]);

  return null;
}

export function DashboardShell({ children }: { children: ReactNode }) {
  return (
    <SidebarProvider>
      <BiaVozProvider>
        <div className="watermark" />
        <TravaGuard />
        <InactivityGuard />
        <VigiaPresenca />
        <div className="app">
          <Backdrop />
          <Sidebar />
          <div className="main">{children}</div>
        </div>
        <button className="vrx">🛟 VRX Support</button>
      </BiaVozProvider>
    </SidebarProvider>
  );
}
