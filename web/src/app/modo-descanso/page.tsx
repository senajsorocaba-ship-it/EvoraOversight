"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { destravar } from "@/lib/trava-tela";
import type { Point } from "@vladmandic/face-api";

// Desbloqueio real pelo rosto — ver `web/src/lib/reconhecimento-facial.ts`
// pro contexto completo do desvio deliberado do Manual (que recomenda
// passkey, não reconhecimento facial próprio) e da contenção adotada
// (nada sai do navegador).
const LIMITE_TENTATIVA_MS = 20000;
const INTERVALO_DETECCAO_MS = 500;
// Duas detecções batendo, separadas no tempo, com uma pequena diferença de
// posição dos pontos de referência entre elas — checagem leve contra uma
// foto estática impressa. NÃO é vivacidade de verdade (sem profundidade,
// sem infravermelho, sem o que um sensor tipo Face ID tem) — é só uma
// barreira a mais, documentada como tal, não escondida.
const DIFERENCA_MINIMA_PONTOS = 0.6;

export default function ModoDescansoPage() {
  const router = useRouter();
  const [carregando, setCarregando] = useState(true);
  const [temDescritor, setTemDescritor] = useState(false);
  const [status, setStatus] = useState("Verificando…");
  const [erroCamera, setErroCamera] = useState<string | null>(null);
  const [expirado, setExpirado] = useState(false);

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const usuarioIdRef = useRef<string | null>(null);
  const ultimaDeteccaoRef = useRef<{ pontos: Point[]; hora: number } | null>(null);

  useEffect(() => {
    let cancelado = false;

    (async () => {
      const supabase = createClient();
      const { data } = await supabase.auth.getUser();
      if (cancelado) return;
      if (!data.user) {
        setCarregando(false);
        return;
      }
      usuarioIdRef.current = data.user.id;
      const { lerDescritorLocal } = await import("@/lib/reconhecimento-facial");
      const registro = lerDescritorLocal(data.user.id);
      if (cancelado) return;
      setTemDescritor(Boolean(registro));
      setCarregando(false);
    })();

    return () => {
      cancelado = true;
    };
  }, []);

  useEffect(() => {
    if (carregando || !temDescritor) return;

    let cancelado = false;
    let intervalo: ReturnType<typeof setInterval> | null = null;
    const limite = setTimeout(() => setExpirado(true), LIMITE_TENTATIVA_MS);

    (async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "user" } });
        if (cancelado) {
          stream.getTracks().forEach((t) => t.stop());
          return;
        }
        streamRef.current = stream;
        const video = document.createElement("video");
        video.muted = true;
        video.playsInline = true;
        video.srcObject = stream;
        await video.play();
        videoRef.current = video;
        setStatus("Olhe pra câmera…");

        const { detectarRosto, distancia, diferencaPontos, LIMIAR_RECONHECIMENTO, lerDescritorLocal } =
          await import("@/lib/reconhecimento-facial");
        const registro = usuarioIdRef.current ? lerDescritorLocal(usuarioIdRef.current) : null;
        if (!registro) {
          setStatus("Rosto não cadastrado neste navegador.");
          return;
        }

        intervalo = setInterval(async () => {
          if (!videoRef.current) return;
          const resultado = await detectarRosto(videoRef.current);
          if (!resultado) {
            ultimaDeteccaoRef.current = null;
            return;
          }
          const dist = distancia(resultado.descritor, registro.descritor);
          if (dist > LIMIAR_RECONHECIMENTO) {
            ultimaDeteccaoRef.current = null;
            return;
          }
          const agora = Date.now();
          const anterior = ultimaDeteccaoRef.current;
          if (
            anterior &&
            agora - anterior.hora >= 500 &&
            diferencaPontos(anterior.pontos, resultado.pontos) >= DIFERENCA_MINIMA_PONTOS
          ) {
            // Duas leituras batendo com o rosto, com um pequeno movimento
            // natural entre elas — desbloqueia.
            destravar();
            router.push("/");
            return;
          }
          ultimaDeteccaoRef.current = { pontos: resultado.pontos, hora: agora };
        }, INTERVALO_DETECCAO_MS);
      } catch (e) {
        console.error("[ModoDescanso] não consegui ligar a câmera:", e);
        setErroCamera("Não consegui acessar a câmera pra reconhecer seu rosto.");
      }
    })();

    return () => {
      cancelado = true;
      if (intervalo) clearInterval(intervalo);
      clearTimeout(limite);
      streamRef.current?.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    };
  }, [carregando, temDescritor, router]);

  async function usarSenha() {
    const supabase = createClient();
    await supabase.auth.signOut();
    destravar();
    router.push("/login");
  }

  // Sem rosto cadastrado neste navegador — nunca aprisiona quem não
  // cadastrou: mantém o comportamento original (clicar em qualquer lugar
  // destrava).
  if (!carregando && !temDescritor) {
    return (
      <>
        <div className="watermark" />
        <Link
          href="/"
          className="rest show"
          id="rest"
          style={{ position: "static", color: "inherit" }}
          onClick={() => destravar()}
        >
          <ConteudoEstatico />
        </Link>
      </>
    );
  }

  return (
    <>
      <div className="watermark" />
      <div className="rest show" id="rest" style={{ position: "static" }}>
        <ConteudoEstatico />
        {!carregando && temDescritor && (
          <div style={{ marginTop: 16 }}>
            {erroCamera ? (
              <p className="login-err">{erroCamera}</p>
            ) : (
              <p style={{ fontSize: 13, opacity: 0.85 }}>{status}</p>
            )}
            {(expirado || erroCamera) && (
              <button
                type="button"
                className="btn"
                style={{ marginTop: 10 }}
                onClick={usarSenha}
              >
                Não reconheci você — usar senha
              </button>
            )}
          </div>
        )}
      </div>
    </>
  );
}

function ConteudoEstatico() {
  return (
    <>
      <div className="shield">
        <svg className="ico" viewBox="0 0 24 24" style={{ width: 30, height: 30 }}>
          <path d="M12 2 4 5v6c0 5 3.4 9 8 11 4.6-2 8-6 8-11V5z" />
        </svg>
      </div>
      <h2 className="serif">Modo descanso</h2>
      <p>Ausência detectada — conteúdo ocultado automaticamente</p>
      <div className="scanpill">📷 Aguardando reconhecimento facial da usuária logada…</div>
      <div className="rcards">
        <div className="rcard"><b>Sessão congelada</b><span>A pesquisa retorna no ponto exato — nada se perde.</span></div>
        <div className="rcard"><b>Tempo configurável</b><span>Descanso após X segundos sem presença (teto por alçada).</span></div>
        <div className="rcard"><b>Rosto não autorizado</b><span>Não desbloqueia · evento registrado na AAS.</span></div>
        <div className="rcard"><b>Processado neste navegador</b><span>Nada é enviado ao Évora — o rosto nunca sai deste computador.</span></div>
      </div>
      <div className="foot">🔒 Évora Oversight · Regra 03 — sigilo físico sem perder o trabalho</div>
    </>
  );
}
