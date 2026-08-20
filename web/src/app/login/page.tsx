"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [verSenha, setVerSenha] = useState(false);
  const [erro, setErro] = useState("");
  const [aviso, setAviso] = useState("");
  const [enviando, setEnviando] = useState(false);

  async function handleSubmit(ev: FormEvent) {
    ev.preventDefault();
    setErro("");
    setAviso("");
    setEnviando(true);

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password: senha,
    });

    if (error) {
      setErro(
        error.message === "Invalid login credentials"
          ? "E-mail ou senha inválidos."
          : error.message
      );
      setEnviando(false);
      return;
    }

    router.push("/");
    router.refresh();
  }

  return (
    <div className="login-page">
      <div className="login-brand">
        <div className="login-mark">
          <svg className="ico" viewBox="0 0 24 24" style={{ width: 30, height: 30 }}>
            <path d="M3 21h18" />
            <path d="M5 21V10" />
            <path d="M19 21V10" />
            <path d="M4 10l8-6 8 6" />
            <path d="M9 21v-7" />
            <path d="M15 21v-7" />
          </svg>
        </div>
        <div className="login-sub">OVERSIGHT</div>
        <div className="login-tag">INTELIGÊNCIA POLÍTICA LEGISLATIVA</div>
      </div>

      <div className="login-card">
        <form onSubmit={handleSubmit}>
          <label htmlFor="email">E-mail funcional</label>
          <input
            id="email"
            type="email"
            autoComplete="username"
            placeholder="seu e-mail do gabinete"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />

          <label htmlFor="senha">Senha</label>
          <div className="login-pass-wrap">
            <input
              id="senha"
              type={verSenha ? "text" : "password"}
              autoComplete="current-password"
              placeholder="sua senha"
              required
              value={senha}
              onChange={(e) => setSenha(e.target.value)}
            />
            <button
              type="button"
              className="login-ver"
              onClick={() => setVerSenha((v) => !v)}
            >
              {verSenha ? "ocultar" : "ver"}
            </button>
          </div>

          <button type="submit" className="login-entrar" disabled={enviando}>
            {enviando ? "Entrando…" : "Entrar"}
          </button>

          {erro && <div className="login-err">{erro}</div>}
          {aviso && <div className="login-aviso">{aviso}</div>}

          <div className="login-actions">
            <button
              type="button"
              onClick={() =>
                setAviso("Cadastro é feito pelo gestor do gabinete — fale com o suporte.")
              }
            >
              Cadastre-se
            </button>
            <button
              type="button"
              onClick={() =>
                setAviso("Recuperação de senha ainda não disponível — fale com o suporte.")
              }
            >
              Esqueci a senha
            </button>
          </div>
        </form>
      </div>

      <div className="login-env">
        Ambiente: {process.env.NEXT_PUBLIC_SUPABASE_URL}
      </div>
    </div>
  );
}
