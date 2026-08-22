"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

const UFS = [
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG",
  "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
];

type Municipio = { id: string; nome: string; slug: string };

export default function CadastroPage() {
  const router = useRouter();

  const [uf, setUf] = useState("");
  const [municipios, setMunicipios] = useState<Municipio[]>([]);
  const [carregandoMunicipios, setCarregandoMunicipios] = useState(false);
  const [municipioId, setMunicipioId] = useState("");
  const [municipioNome, setMunicipioNome] = useState("");

  const [email, setEmail] = useState("");
  const [verificando, setVerificando] = useState(false);
  const [elegivel, setElegivel] = useState<boolean | null>(null);
  const [nomeVereador, setNomeVereador] = useState("");

  const [senha, setSenha] = useState("");
  const [confirmarSenha, setConfirmarSenha] = useState("");
  const [enviando, setEnviando] = useState(false);
  const [sucesso, setSucesso] = useState<"login" | "confirmar-email" | null>(null);

  const [erro, setErro] = useState("");

  async function handleUfChange(novaUf: string) {
    setUf(novaUf);
    setMunicipioId("");
    setMunicipioNome("");
    setMunicipios([]);
    resetVerificacao();
    if (!novaUf) return;

    setCarregandoMunicipios(true);
    setErro("");
    const supabase = createClient();
    const { data, error } = await supabase.rpc("evora_listar_municipios_uf", { p_uf: novaUf });
    setCarregandoMunicipios(false);

    if (error) {
      setErro("Não foi possível carregar as cidades disponíveis. Tente novamente.");
      return;
    }
    setMunicipios((data as Municipio[]) ?? []);
  }

  function handleMunicipioChange(id: string) {
    setMunicipioId(id);
    setMunicipioNome(municipios.find((m) => m.id === id)?.nome ?? "");
    resetVerificacao();
  }

  function resetVerificacao() {
    setElegivel(null);
    setNomeVereador("");
    setSenha("");
    setConfirmarSenha("");
    setErro("");
  }

  async function handleVerificar() {
    if (!municipioId || !email.trim()) return;
    setVerificando(true);
    setErro("");
    setElegivel(null);

    const supabase = createClient();
    const { data, error } = await supabase.rpc("evora_verificar_vereador", {
      p_municipio_id: municipioId,
      p_email: email.trim(),
    });
    setVerificando(false);

    if (error) {
      setErro("Não foi possível verificar o e-mail agora. Tente novamente.");
      return;
    }
    const match = Array.isArray(data) && data.length > 0 ? data[0] : null;
    if (!match) {
      setElegivel(false);
      setErro(
        `Este e-mail não consta na lista de vereadores verificados de ${municipioNome} — fale com o suporte.`
      );
      return;
    }
    setElegivel(true);
    setNomeVereador(match.nome as string);
  }

  async function handleSubmit(ev: FormEvent) {
    ev.preventDefault();
    setErro("");

    if (senha.length < 6) {
      setErro("A senha precisa ter pelo menos 6 caracteres.");
      return;
    }
    if (senha !== confirmarSenha) {
      setErro("As senhas não coincidem.");
      return;
    }

    setEnviando(true);
    const supabase = createClient();

    const { error: rpcError } = await supabase.rpc("evora_autocadastro_vereador", {
      p_municipio_id: municipioId,
      p_email: email.trim(),
    });
    if (rpcError) {
      setEnviando(false);
      setErro(rpcError.message || "Não foi possível concluir o cadastro.");
      return;
    }

    const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
      email: email.trim(),
      password: senha,
    });
    setEnviando(false);

    if (signUpError) {
      setErro(
        `Sua conta foi registrada, mas a criação do login falhou (${signUpError.message}). Fale com o suporte para concluir.`
      );
      return;
    }

    if (signUpData.session) {
      router.push("/");
      router.refresh();
      return;
    }
    setSucesso("confirmar-email");
  }

  if (sucesso === "confirmar-email") {
    return (
      <div className="login-page">
        <div className="login-card">
          <p className="login-aviso" style={{ marginTop: 0 }}>
            Cadastro concluído! Enviamos um e-mail de confirmação para{" "}
            <strong>{email.trim()}</strong> — confirme para poder entrar.
          </p>
          <Link href="/login" className="login-cadastro-link" style={{ display: "block", marginTop: 16 }}>
            Ir para o login
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="login-page">
      <div className="login-brand">
        <div className="login-sub">EVORA OVERSIGHT</div>
        <div className="login-tag">CADASTRO DE VEREADOR(A)</div>
      </div>

      <div className="login-card">
        <form onSubmit={handleSubmit}>
          <label htmlFor="uf">Estado</label>
          <select id="uf" value={uf} onChange={(e) => handleUfChange(e.target.value)} required>
            <option value="">selecione</option>
            {UFS.map((sigla) => (
              <option key={sigla} value={sigla}>
                {sigla}
              </option>
            ))}
          </select>

          <label htmlFor="municipio">Cidade</label>
          <select
            id="municipio"
            value={municipioId}
            onChange={(e) => handleMunicipioChange(e.target.value)}
            required
            disabled={!uf || carregandoMunicipios}
          >
            <option value="">
              {!uf
                ? "selecione o estado primeiro"
                : carregandoMunicipios
                ? "carregando…"
                : municipios.length === 0
                ? "nenhuma cidade disponível ainda"
                : "selecione"}
            </option>
            {municipios.map((m) => (
              <option key={m.id} value={m.id}>
                {m.nome}
              </option>
            ))}
          </select>

          {municipioId && (
            <>
              <label htmlFor="email">E-mail</label>
              <div className="login-pass-wrap">
                <input
                  id="email"
                  type="email"
                  placeholder="seu e-mail institucional"
                  required
                  value={email}
                  onChange={(e) => {
                    setEmail(e.target.value);
                    resetVerificacao();
                  }}
                />
                <button
                  type="button"
                  className="login-ver"
                  onClick={handleVerificar}
                  disabled={!email.trim() || verificando}
                >
                  {verificando ? "verificando…" : "verificar"}
                </button>
              </div>
            </>
          )}

          {elegivel && (
            <>
              <p className="login-aviso" style={{ margin: "14px 0 0" }}>
                Confirma que você é <strong>{nomeVereador}</strong>?
              </p>

              <label htmlFor="senha">Senha</label>
              <input
                id="senha"
                type="password"
                autoComplete="new-password"
                required
                value={senha}
                onChange={(e) => setSenha(e.target.value)}
              />

              <label htmlFor="confirmarSenha">Confirmar senha</label>
              <input
                id="confirmarSenha"
                type="password"
                autoComplete="new-password"
                required
                value={confirmarSenha}
                onChange={(e) => setConfirmarSenha(e.target.value)}
              />

              <button type="submit" className="login-entrar" disabled={enviando}>
                {enviando ? "Criando conta…" : "Criar conta"}
              </button>
            </>
          )}

          {erro && <div className="login-err">{erro}</div>}
        </form>

        <div className="login-actions">
          <Link href="/login" className="login-cadastro-link">
            Já tenho conta
          </Link>
        </div>
      </div>
    </div>
  );
}
