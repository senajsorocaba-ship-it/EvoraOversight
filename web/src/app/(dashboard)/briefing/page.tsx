"use client";

import { useEffect, useState } from "react";
import { Topbar } from "@/components/topbar";
import { FooterLegal } from "@/components/footer-legal";
import { createClient } from "@/lib/supabase/client";

type Briefing = {
  id: string;
  mundo: string;
  data_referencia: string;
  html: string | null;
  ciencia_por: string | null;
  ciencia_em: string | null;
};

export default function BriefingPage() {
  const [carregando, setCarregando] = useState(true);
  const [briefings, setBriefings] = useState<Briefing[]>([]);
  const [usuarioId, setUsuarioId] = useState<string | null>(null);
  const [podeDarCiencia, setPodeDarCiencia] = useState(false);
  const [erro, setErro] = useState("");
  const [dandoCiencia, setDandoCiencia] = useState<string | null>(null);

  useEffect(() => {
    carregar();
  }, []);

  async function carregar() {
    setCarregando(true);
    setErro("");
    const supabase = createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setCarregando(false);
      return;
    }

    const { data: usuario } = await supabase
      .from("usuarios")
      .select("id, alcada_aprovacao")
      .eq("auth_user_id", user.id)
      .maybeSingle();
    if (usuario) {
      setUsuarioId(usuario.id as string);
      setPodeDarCiencia(Boolean(usuario.alcada_aprovacao));
    }

    const { data, error } = await supabase
      .from("briefings")
      .select("id, mundo, data_referencia, html, ciencia_por, ciencia_em")
      .eq("ativo", true)
      .order("data_referencia", { ascending: false })
      .limit(6);

    setCarregando(false);
    if (error) {
      setErro("Não foi possível carregar o briefing agora. Tente novamente.");
      return;
    }

    const maisRecentePorMundo = new Map<string, Briefing>();
    for (const b of (data as Briefing[]) ?? []) {
      if (!maisRecentePorMundo.has(b.mundo)) maisRecentePorMundo.set(b.mundo, b);
    }
    setBriefings(Array.from(maisRecentePorMundo.values()));
  }

  async function darCiencia(id: string) {
    if (!usuarioId) return;
    setDandoCiencia(id);
    const supabase = createClient();
    const { error } = await supabase
      .from("briefings")
      .update({ ciencia_por: usuarioId })
      .eq("id", id);
    setDandoCiencia(null);
    if (error) {
      setErro("Não foi possível registrar a ciência agora. Tente novamente.");
      return;
    }
    carregar();
  }

  return (
    <>
      <Topbar
        title="Briefing Matinal"
        subtitle="Leitura do dia · ciência exigida antes de qualquer ato de efeito externo"
      />

      <main className="content">
        {carregando && <div className="card">Carregando…</div>}

        {!carregando && erro && (
          <div className="card">
            <p className="login-err">{erro}</p>
          </div>
        )}

        {!carregando && !erro && briefings.length === 0 && (
          <div className="card">
            <p>Nenhum briefing gerado ainda.</p>
          </div>
        )}

        {briefings.map((b) => (
          <div className="card" key={b.id} style={{ marginBottom: 20 }}>
            <h3>
              {b.mundo === "gabinete" ? "Gabinete" : "Campanha"} — {b.data_referencia}
            </h3>

            {b.html ? (
              <iframe
                srcDoc={b.html}
                title={`Briefing ${b.mundo} ${b.data_referencia}`}
                style={{ width: "100%", minHeight: 640, border: "none", marginTop: 12 }}
              />
            ) : (
              <p>Briefing sendo preparado — dados agregados, texto ainda pendente.</p>
            )}

            {b.ciencia_por ? (
              <p className="login-aviso" style={{ marginTop: 12 }}>
                Ciência dada em {new Date(b.ciencia_em as string).toLocaleString("pt-BR")}.
              </p>
            ) : podeDarCiencia ? (
              <button
                type="button"
                className="login-entrar"
                style={{ marginTop: 12 }}
                onClick={() => darCiencia(b.id)}
                disabled={dandoCiencia === b.id}
              >
                {dandoCiencia === b.id ? "Registrando…" : "Dar ciência"}
              </button>
            ) : null}
          </div>
        ))}
      </main>

      <FooterLegal />
    </>
  );
}
