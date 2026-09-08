"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { travar } from "@/lib/trava-tela";

const INTERVALO_CHECAGEM_MS = 3000;
const AUSENCIAS_SEGUIDAS_PARA_TRAVAR = 3; // ~9s sem rosto (3 x 3s)

// Vigia de presença contínua — parte do reconhecimento facial do modo
// descanso (ver `web/src/lib/reconhecimento-facial.ts` pro contexto
// completo do desvio deliberado do Manual e da contenção adotada).
//
// Só liga a câmera se o usuário logado já cadastrou o rosto (em
// Configurações) — quem nunca cadastrou nunca tem a câmera acionada por
// este componente. Roda IN­DEPENDENTE do InactivityGuard (que trava por
// mouse/teclado parado, e que fica suspenso enquanto a Bia está ouvindo) —
// sair da frente do computador enquanto fala com a Bia ainda deve travar
// por ausência.
export function VigiaPresenca() {
  const router = useRouter();
  const pathname = usePathname();
  const [ativo, setAtivo] = useState(false);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const ausenciasRef = useRef(0);
  const intervaloRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const usuarioIdRef = useRef<string | null>(null);

  // Descobre se há um rosto cadastrado pra este usuário — só então liga a
  // câmera. Refeito a cada troca de rota porque o usuário pode ter acabado
  // de cadastrar em Configurações nesta mesma sessão. Não roda em
  // /modo-descanso — quem verifica presença ali é a própria página, com o
  // fluxo de desbloqueio.
  useEffect(() => {
    if (pathname === "/modo-descanso") return;
    let cancelado = false;
    (async () => {
      const supabase = createClient();
      const { data } = await supabase.auth.getUser();
      if (cancelado || !data.user) return;
      usuarioIdRef.current = data.user.id;
      const { lerDescritorLocal } = await import("@/lib/reconhecimento-facial");
      const registro = lerDescritorLocal(data.user.id);
      if (!cancelado) setAtivo(Boolean(registro));
    })();
    return () => {
      cancelado = true;
    };
  }, [pathname]);

  // Fora de /modo-descanso E com rosto cadastrado — é quando a câmera
  // deste componente deve rodar de verdade.
  const rodando = ativo && pathname !== "/modo-descanso";

  useEffect(() => {
    if (!rodando) return;

    let cancelado = false;

    async function ligar() {
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

        const { detectarRosto } = await import("@/lib/reconhecimento-facial");
        ausenciasRef.current = 0;

        intervaloRef.current = setInterval(async () => {
          if (!videoRef.current) return;
          try {
            const resultado = await detectarRosto(videoRef.current);
            if (resultado) {
              ausenciasRef.current = 0;
            } else {
              ausenciasRef.current += 1;
              if (ausenciasRef.current >= AUSENCIAS_SEGUIDAS_PARA_TRAVAR) {
                travar(router);
              }
            }
          } catch (e) {
            console.error("[VigiaPresenca] erro detectando rosto:", e);
          }
        }, INTERVALO_CHECAGEM_MS);
      } catch (e) {
        // Câmera negada/indisponível — não trava sozinho por ausência,
        // mas avisa (nunca falha em silêncio); o timer de inatividade
        // normal continua valendo como rede de segurança.
        console.error("[VigiaPresenca] não consegui ligar a câmera:", e);
      }
    }

    ligar();

    return () => {
      cancelado = true;
      if (intervaloRef.current) clearInterval(intervaloRef.current);
      streamRef.current?.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
      videoRef.current = null;
    };
  }, [rodando, router]);

  if (!rodando) return null;

  return (
    <div
      style={{
        position: "fixed",
        bottom: 12,
        left: 12,
        zIndex: 40,
        fontSize: 11,
        padding: "4px 10px",
        borderRadius: 999,
        background: "rgba(47,107,70,.25)",
        color: "#5fae7e",
        border: "1px solid rgba(95,174,126,.4)",
      }}
      title="A câmera está checando presença pra travar a tela sozinha quando você sair"
    >
      👁 presença ativa
    </div>
  );
}
