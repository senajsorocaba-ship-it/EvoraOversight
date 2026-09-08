"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";

const AMOSTRAS_NECESSARIAS = 5;
const INTERVALO_AMOSTRA_MS = 400;

export function EnrolamentoFacial() {
  const [usuarioId, setUsuarioId] = useState<string | null>(null);
  const [cadastradoEm, setCadastradoEm] = useState<string | null>(null);
  const [capturando, setCapturando] = useState(false);
  const [progresso, setProgresso] = useState(0);
  const [erro, setErro] = useState<string | null>(null);
  const [mostrarAviso, setMostrarAviso] = useState(false);

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);

  useEffect(() => {
    let cancelado = false;
    (async () => {
      const supabase = createClient();
      const { data } = await supabase.auth.getUser();
      if (cancelado || !data.user) return;
      setUsuarioId(data.user.id);
      const { lerDescritorLocal } = await import("@/lib/reconhecimento-facial");
      const registro = lerDescritorLocal(data.user.id);
      if (registro) setCadastradoEm(registro.criadoEm);
    })();
    return () => {
      cancelado = true;
    };
  }, []);

  const encerrarCamera = useCallback(() => {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
  }, []);

  useEffect(() => encerrarCamera, [encerrarCamera]);

  async function iniciarCadastro() {
    if (!usuarioId) {
      setErro("Não consegui confirmar seu usuário logado — recarregue a página e tente de novo.");
      return;
    }
    setErro(null);
    setProgresso(0);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "user" } });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
    } catch (e) {
      console.error("[EnrolamentoFacial] getUserMedia falhou:", e);
      setErro(
        "Não consegui acessar a câmera — verifique se você permitiu o acesso ou se outro programa está usando ela."
      );
      return;
    }

    setCapturando(true);
    try {
      const { carregarModelos, detectarRosto, mediaDescritores, salvarDescritorLocal } = await import(
        "@/lib/reconhecimento-facial"
      );
      await carregarModelos();

      const amostras: Float32Array[] = [];
      while (amostras.length < AMOSTRAS_NECESSARIAS) {
        if (!videoRef.current) break;
        const resultado = await detectarRosto(videoRef.current);
        if (resultado) {
          amostras.push(resultado.descritor);
          setProgresso(amostras.length);
        }
        await new Promise((r) => setTimeout(r, INTERVALO_AMOSTRA_MS));
      }

      if (amostras.length < AMOSTRAS_NECESSARIAS) {
        setErro("Não consegui capturar seu rosto direito — tente de novo com mais luz, olhando pra câmera.");
        return;
      }

      const descritorFinal = mediaDescritores(amostras);
      const salvou = salvarDescritorLocal(usuarioId, descritorFinal);
      if (!salvou) {
        setErro("Capturei seu rosto, mas não consegui salvar neste navegador (armazenamento local bloqueado).");
        return;
      }
      setCadastradoEm(new Date().toISOString());
    } catch (e) {
      console.error("[EnrolamentoFacial] falha durante a captura:", e);
      setErro("Algo deu errado durante a captura. Tente de novo.");
    } finally {
      setCapturando(false);
      encerrarCamera();
    }
  }

  async function removerCadastro() {
    if (!usuarioId) return;
    const { limparDescritorLocal } = await import("@/lib/reconhecimento-facial");
    limparDescritorLocal(usuarioId);
    setCadastradoEm(null);
  }

  return (
    <div className="cfg-card" style={{ gridColumn: "1 / -1" }}>
      <div className="cic" style={{ background: "rgba(47,107,70,.3)", color: "#5fae7e" }}>
        <svg className="ico" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="9" />
          <circle cx="9" cy="10" r="1" />
          <circle cx="15" cy="10" r="1" />
          <path d="M8 15c1 1 2.5 1.5 4 1.5s3-.5 4-1.5" />
        </svg>
      </div>
      <h4>Reconhecimento facial (modo descanso)</h4>
      <p style={{ marginBottom: 10 }}>
        Cadastre seu rosto pra travar a tela sozinha quando você sair de perto do computador, e
        destravar só mostrando o rosto de novo.
      </p>

      <p style={{ fontSize: 12, opacity: 0.8, marginBottom: 10 }}>
        ⚠ Isto é diferente da passkey (Face ID/Windows Hello) que o Manual do Évora recomenda: aqui
        quem reconhece o rosto é este site, rodando só no seu navegador — a captura nunca é enviada
        a nenhum servidor, fica salva só neste computador/navegador (some se você limpar os dados do
        navegador, e não funciona em outro aparelho). Se preferir a alternativa mais segura, use a
        biometria do próprio sistema operacional pra desbloquear o computador.
      </p>

      {!mostrarAviso && !cadastradoEm && (
        <button type="button" className="btn" onClick={() => setMostrarAviso(true)}>
          Cadastrar meu rosto
        </button>
      )}

      {mostrarAviso && !cadastradoEm && !capturando && (
        <div>
          <p style={{ fontSize: 13, marginBottom: 8 }}>
            Vou pedir acesso à câmera e capturar {AMOSTRAS_NECESSARIAS} instantâneos do seu rosto, só
            pra calcular um código numérico de comparação — nenhuma imagem fica guardada, só esse
            código. Olhe pra câmera com boa luz.
          </p>
          <button type="button" className="btn" onClick={iniciarCadastro}>
            Entendi, ligar câmera
          </button>
        </div>
      )}

      {capturando && (
        <div>
          <video ref={videoRef} muted playsInline style={{ width: 240, borderRadius: 8, background: "#000" }} />
          <p style={{ fontSize: 13, marginTop: 6 }}>
            Capturando… {progresso}/{AMOSTRAS_NECESSARIAS}
          </p>
        </div>
      )}

      {cadastradoEm && !capturando && (
        <div>
          <p style={{ fontSize: 13, marginBottom: 8 }}>
            ✅ Rosto cadastrado neste navegador em {new Date(cadastradoEm).toLocaleString("pt-BR")}.
          </p>
          <button type="button" className="btn" onClick={removerCadastro}>
            Remover cadastro
          </button>
        </div>
      )}

      {erro && (
        <p className="login-err" style={{ marginTop: 10 }}>
          {erro}
        </p>
      )}
    </div>
  );
}
