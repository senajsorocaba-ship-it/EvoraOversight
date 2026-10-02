"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";

const MAX_TEMA_LEN = 80;
const MAX_TEMAS = 25;

export function AssuntosInteresse() {
  const [temas, setTemas] = useState<string[]>([]);
  const [novoTema, setNovoTema] = useState("");
  const [carregando, setCarregando] = useState(true);
  const [salvando, setSalvando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [salvo, setSalvo] = useState(false);

  useEffect(() => {
    let cancelado = false;
    (async () => {
      const supabase = createClient();
      // RLS (tenants_isolamento: id = evora_tenant_atual()) já restringe
      // a leitura ao próprio tenant — nenhum .eq(tenant_id) precisa ser
      // escrito (mesmo padrão já usado em api/bia/route.ts).
      const { data, error } = await supabase.from("tenants").select("perfil").maybeSingle();
      if (cancelado) return;
      if (error) {
        setErro("Não consegui carregar os assuntos salvos — recarregue a página.");
      } else {
        const perfil = (data?.perfil ?? {}) as {
          temas_prioritarios?: string[];
          temas?: string[];
        };
        setTemas(perfil.temas_prioritarios ?? perfil.temas ?? []);
      }
      setCarregando(false);
    })();
    return () => {
      cancelado = true;
    };
  }, []);

  function adicionarTema() {
    const t = novoTema.trim();
    if (!t) return;
    if (t.length > MAX_TEMA_LEN) {
      setErro(`Esse assunto é muito longo (máximo ${MAX_TEMA_LEN} caracteres).`);
      return;
    }
    if (temas.some((x) => x.toLowerCase() === t.toLowerCase())) {
      setNovoTema("");
      return;
    }
    if (temas.length >= MAX_TEMAS) {
      setErro(`Máximo de ${MAX_TEMAS} assuntos — remova algum antes de adicionar outro.`);
      return;
    }
    setErro(null);
    setSalvo(false);
    setTemas([...temas, t]);
    setNovoTema("");
  }

  function removerTema(alvo: string) {
    setSalvo(false);
    setTemas(temas.filter((t) => t !== alvo));
  }

  async function salvar() {
    setSalvando(true);
    setErro(null);
    setSalvo(false);
    const supabase = createClient();
    const { data, error } = await supabase.rpc("evora_atualizar_temas_prioritarios", {
      p_temas: temas,
    });
    if (error) {
      console.error("[AssuntosInteresse] falha ao salvar:", error);
      setErro("Não consegui salvar — tente de novo em instantes.");
    } else {
      setTemas((data as string[] | null) ?? temas);
      setSalvo(true);
    }
    setSalvando(false);
  }

  return (
    <div className="cfg-card temas-card" style={{ gridColumn: "1 / -1" }}>
      <div className="cic" style={{ background: "rgba(43,84,120,.3)", color: "#8fbfe0" }}>
        <svg className="ico" viewBox="0 0 24 24">
          <path d="M20.59 13.41 11 3.83A2 2 0 0 0 9.59 3.17L3 3a1 1 0 0 0-1 1l.17 6.59a2 2 0 0 0 .66 1.41l9.59 9.59a2 2 0 0 0 2.83 0l6-6a2 2 0 0 0 0-2.83z" />
          <circle cx="7.5" cy="7.5" r="1.3" />
        </svg>
      </div>
      <h4>Assuntos de Interesse</h4>
      <p style={{ marginBottom: 12 }}>
        Temas que a Bia prioriza todo dia de manhã, ao redigir o Briefing — ex.: &ldquo;saúde&rdquo;,
        &ldquo;mobilidade urbana&rdquo;, &ldquo;licitações de obras&rdquo;.
      </p>

      {carregando ? (
        <p style={{ fontSize: 13, color: "var(--mut)" }}>Carregando…</p>
      ) : (
        <>
          <div className="temas-lista">
            {temas.length === 0 && (
              <span style={{ fontSize: 12.5, color: "var(--mut)" }}>
                Nenhum assunto cadastrado ainda.
              </span>
            )}
            {temas.map((t) => (
              <span key={t} className="temas-chip">
                {t}
                <button type="button" aria-label={`Remover ${t}`} onClick={() => removerTema(t)}>
                  ×
                </button>
              </span>
            ))}
          </div>

          <div className="temas-add">
            <input
              type="text"
              placeholder="Digite um assunto e tecle Enter"
              value={novoTema}
              maxLength={MAX_TEMA_LEN}
              onChange={(e) => setNovoTema(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  adicionarTema();
                }
              }}
            />
            <button type="button" className="temas-add-btn" onClick={adicionarTema}>
              Adicionar
            </button>
          </div>

          <button
            type="button"
            className="login-entrar temas-salvar"
            onClick={salvar}
            disabled={salvando}
          >
            {salvando ? "Salvando…" : "Salvar assuntos"}
          </button>

          {erro && (
            <p className="login-err" style={{ textAlign: "left", marginTop: 10 }}>
              {erro}
            </p>
          )}
          {salvo && !erro && (
            <p className="login-aviso" style={{ textAlign: "left", marginTop: 10 }}>
              Salvo — a Bia já vai usar isso no próximo Briefing.
            </p>
          )}
        </>
      )}
    </div>
  );
}
