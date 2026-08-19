"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { SidebarProvider, useSidebar } from "@/components/sidebar-context";
import { Sidebar } from "@/components/sidebar";

const REST_SEGUNDOS = 120;

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
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
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
  }, [router]);

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
