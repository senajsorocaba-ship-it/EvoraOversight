"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [erro, setErro] = useState("");
  const [enviando, setEnviando] = useState(false);

  async function handleSubmit(ev: FormEvent) {
    ev.preventDefault();
    setErro("");
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
      <div className="login-card">
        <div className="login-brand">
          ÉVORA <b>OVERSIGHT</b>
        </div>
        <h1>Entrar no Gabinete</h1>
        <form onSubmit={handleSubmit}>
          <label htmlFor="email">E-mail</label>
          <input
            id="email"
            type="email"
            autoComplete="username"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
          <label htmlFor="senha">Senha</label>
          <input
            id="senha"
            type="password"
            autoComplete="current-password"
            required
            value={senha}
            onChange={(e) => setSenha(e.target.value)}
          />
          <button type="submit" disabled={enviando}>
            {enviando ? "Entrando…" : "Entrar"}
          </button>
          <div className="login-err">{erro}</div>
        </form>
        <div className="login-env">
          Ambiente: {process.env.NEXT_PUBLIC_SUPABASE_URL}
        </div>
      </div>
    </div>
  );
}
