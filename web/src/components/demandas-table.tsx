"use client";

import { useMemo, useState } from "react";
import { ClickableRow } from "@/components/clickable-row";

type Demanda = {
  protocolo: string;
  cidadao: string;
  assunto: string;
  area: string;
  canal: string;
  prazo: string;
  statusFiltro: "aberta" | "andamento" | "atrasada" | "concluida" | "critica";
  statusLabel: string;
  badgeClass: string;
  href?: string;
};

const DEMANDAS: Demanda[] = [
  { protocolo: "#2026-1042", cidadao: "Maria S. Lima", assunto: "Falta de médico no posto", area: "Saúde", canal: "WhatsApp", prazo: "em 2 dias", statusFiltro: "andamento", statusLabel: "Em andamento", badgeClass: "andamento", href: "/demandas/552" },
  { protocolo: "#2026-1041", cidadao: "João P. Alves", assunto: "Buraco na via – Rua das Flores", area: "Obras", canal: "Presencial", prazo: "hoje", statusFiltro: "critica", statusLabel: "Crítica", badgeClass: "critica", href: "/demandas/552" },
  { protocolo: "#2026-1039", cidadao: "Ana C. Rocha", assunto: "Vaga em creche", area: "Educação", canal: "WhatsApp", prazo: "em 5 dias", statusFiltro: "aberta", statusLabel: "Aberta", badgeClass: "aberta" },
  { protocolo: "#2026-1037", cidadao: "Carlos M.", assunto: "Iluminação queimada", area: "Infraestrutura", canal: "Telefone", prazo: "em 3 dias", statusFiltro: "andamento", statusLabel: "Em andamento", badgeClass: "andamento" },
  { protocolo: "#2026-1034", cidadao: "Beatriz N.", assunto: "Transporte escolar atrasado", area: "Transporte", canal: "WhatsApp", prazo: "atrasada", statusFiltro: "atrasada", statusLabel: "Atrasada", badgeClass: "atrasada" },
  { protocolo: "#2026-1031", cidadao: "Rafael T.", assunto: "Coleta de lixo irregular", area: "Infraestrutura", canal: "Presencial", prazo: "em 6 dias", statusFiltro: "aberta", statusLabel: "Aberta", badgeClass: "aberta" },
  { protocolo: "#2026-1029", cidadao: "Lúcia F.", assunto: "Pedido de cadeira de rodas", area: "Assistência", canal: "WhatsApp", prazo: "concluída", statusFiltro: "concluida", statusLabel: "Concluída", badgeClass: "concluida" },
  { protocolo: "#2026-1026", cidadao: "Pedro H.", assunto: "Poda de árvore", area: "Obras", canal: "Telefone", prazo: "em 4 dias", statusFiltro: "andamento", statusLabel: "Em andamento", badgeClass: "andamento" },
];

const ABAS: { label: string; filtro: Demanda["statusFiltro"] | "todas" }[] = [
  { label: "Todas", filtro: "todas" },
  { label: "Abertas", filtro: "aberta" },
  { label: "Em andamento", filtro: "andamento" },
  { label: "Atrasadas", filtro: "atrasada" },
  { label: "Concluídas", filtro: "concluida" },
];

const REGEX_DIACRITICOS = /[̀-ͯ]/g;

function normalizar(txt: string) {
  return txt.normalize("NFD").replace(REGEX_DIACRITICOS, "").toLowerCase();
}

export function DemandasTable() {
  const [aba, setAba] = useState<(typeof ABAS)[number]["filtro"]>("todas");
  const [busca, setBusca] = useState("");

  const filtradas = useMemo(() => {
    const termo = normalizar(busca.trim());
    return DEMANDAS.filter((d) => {
      if (aba !== "todas" && d.statusFiltro !== aba) return false;
      if (!termo) return true;
      return (
        normalizar(d.protocolo).includes(termo) ||
        normalizar(d.cidadao).includes(termo) ||
        normalizar(d.assunto).includes(termo)
      );
    });
  }, [aba, busca]);

  return (
    <>
      <div className="filters">
        {ABAS.map((a) => (
          <div
            key={a.filtro}
            className={"ftab" + (aba === a.filtro ? " active" : "")}
            onClick={() => setAba(a.filtro)}
          >
            {a.label}
          </div>
        ))}
        <div className="search">
          <input
            type="text"
            placeholder="🔍 Buscar protocolo, cidadão ou assunto…"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
          />
        </div>
      </div>

      <div className="card">
        <h3>Fila de demandas — {filtradas.length} exibida{filtradas.length === 1 ? "" : "s"} de {DEMANDAS.length}</h3>
        <div className="tablewrap">
          <table>
            <thead>
              <tr><th>Protocolo</th><th>Cidadão</th><th>Assunto</th><th>Área</th><th>Canal</th><th>Prazo</th><th>Status</th></tr>
            </thead>
            <tbody>
              {filtradas.map((d) =>
                d.href ? (
                  <ClickableRow key={d.protocolo} href={d.href}>
                    <td>{d.protocolo}</td><td>{d.cidadao}</td><td>{d.assunto}</td><td>{d.area}</td>
                    <td><span className="chip">{d.canal}</span></td><td>{d.prazo}</td>
                    <td><span className={"badge " + d.badgeClass}>{d.statusLabel}</span></td>
                  </ClickableRow>
                ) : (
                  <tr key={d.protocolo}>
                    <td>{d.protocolo}</td><td>{d.cidadao}</td><td>{d.assunto}</td><td>{d.area}</td>
                    <td><span className="chip">{d.canal}</span></td><td>{d.prazo}</td>
                    <td><span className={"badge " + d.badgeClass}>{d.statusLabel}</span></td>
                  </tr>
                )
              )}
              {filtradas.length === 0 && (
                <tr><td colSpan={7} style={{ textAlign: "center", color: "var(--mut)" }}>Nenhuma demanda encontrada.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
