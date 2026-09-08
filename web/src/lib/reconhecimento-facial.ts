// Reconhecimento facial do modo descanso — DESVIO DELIBERADO do que o
// Manual do Évora recomenda (Fase "step-up": passkey nativa do sistema
// operacional, nunca reconhecimento facial próprio — ver
// `Evora Manual v10 9 1.md`, por volta das linhas 1300-1309 e 3666: "não
// recomendado... exige DPIA... não se liga agora"). O usuário foi avisado
// disso explicitamente e escolheu seguir mesmo assim (ver
// `ao-SUPABASE-BLOCO1/CLAUDE.md`, seção "Reconhecimento facial no modo
// descanso").
//
// Contenção adotada pra reduzir o risco ao mínimo possível dentro dessa
// escolha: o rosto — e o descritor numérico derivado dele — NUNCA sai
// deste navegador. Nada é enviado ao servidor do Évora. Nenhuma tabela,
// nenhuma migration, nenhuma rota de API existe pra isso. Tudo fica no
// `localStorage`, escopado por usuário, só neste navegador/aparelho.
//
// Client-only: mexe com `window`/canvas/WebGL — nunca pode ser importado
// num Server Component nem executar durante SSR.

import * as faceapi from "@vladmandic/face-api";

const CAMINHO_MODELOS = "/models";

// Distância euclidiana máxima entre dois descritores pra considerar "é a
// mesma pessoa" — 0.5 é o padrão conservador mais usado com este modelo
// (face_recognition_model). Menor = mais rigoroso (mais falso negativo);
// maior = mais tolerante (mais falso positivo). Ajustável se o uso real
// mostrar necessidade.
export const LIMIAR_RECONHECIMENTO = 0.5;

let promessaModelos: Promise<void> | null = null;

// Carrega os 3 modelos uma única vez (promise memorizada — chamadas
// concorrentes ganham a mesma promise em vez de disparar downloads
// duplicados).
export function carregarModelos(): Promise<void> {
  if (typeof window === "undefined") {
    return Promise.reject(new Error("carregarModelos() só pode rodar no navegador."));
  }
  if (!promessaModelos) {
    promessaModelos = Promise.all([
      faceapi.nets.tinyFaceDetector.loadFromUri(CAMINHO_MODELOS),
      faceapi.nets.faceLandmark68Net.loadFromUri(CAMINHO_MODELOS),
      faceapi.nets.faceRecognitionNet.loadFromUri(CAMINHO_MODELOS),
    ]).then(() => undefined);
  }
  return promessaModelos;
}

// Roda detector + pontos de referência + descritor num único frame de
// vídeo. Devolve o descritor (128 números) e os pontos de referência
// (usados pela checagem leve de vivacidade em modo-descanso), ou null se
// nenhum rosto foi encontrado no frame.
export async function detectarRosto(
  video: HTMLVideoElement
): Promise<{ descritor: Float32Array; pontos: faceapi.Point[] } | null> {
  await carregarModelos();
  const resultado = await faceapi
    .detectSingleFace(video, new faceapi.TinyFaceDetectorOptions())
    .withFaceLandmarks()
    .withFaceDescriptor();
  if (!resultado) return null;
  return { descritor: resultado.descriptor, pontos: resultado.landmarks.positions };
}

export function distancia(a: Float32Array | number[], b: Float32Array | number[]): number {
  return faceapi.euclideanDistance(a, b);
}

// Diferença média de posição dos pontos de referência entre dois frames —
// usado como checagem leve contra uma foto estática (uma foto impressa
// segurada na frente da câmera não se move nem um pixel entre dois
// frames; um rosto de verdade sempre tem um micro-tremor). NÃO é
// vivacidade de verdade (sem profundidade, sem infravermelho) — é só uma
// barreira a mais, documentada como tal.
export function diferencaPontos(
  a: faceapi.Point[],
  b: faceapi.Point[]
): number {
  if (a.length !== b.length || a.length === 0) return Infinity;
  let soma = 0;
  for (let i = 0; i < a.length; i++) {
    soma += Math.hypot(a[i].x - b[i].x, a[i].y - b[i].y);
  }
  return soma / a.length;
}

function chave(usuarioId: string) {
  return `evora-face-${usuarioId}`;
}

type DescritorSalvo = {
  descritor: number[];
  amostras: number;
  criadoEm: string;
};

export function salvarDescritorLocal(usuarioId: string, descritor: Float32Array): boolean {
  try {
    const registro: DescritorSalvo = {
      descritor: Array.from(descritor),
      amostras: 1,
      criadoEm: new Date().toISOString(),
    };
    window.localStorage.setItem(chave(usuarioId), JSON.stringify(registro));
    return true;
  } catch (e) {
    console.error("[reconhecimento-facial] não consegui salvar no localStorage:", e);
    return false;
  }
}

export function lerDescritorLocal(usuarioId: string): DescritorSalvo | null {
  try {
    const bruto = window.localStorage.getItem(chave(usuarioId));
    if (!bruto) return null;
    const registro = JSON.parse(bruto) as DescritorSalvo;
    if (!Array.isArray(registro.descritor) || registro.descritor.length === 0) return null;
    return registro;
  } catch (e) {
    console.error("[reconhecimento-facial] não consegui ler do localStorage:", e);
    return null;
  }
}

export function limparDescritorLocal(usuarioId: string): void {
  try {
    window.localStorage.removeItem(chave(usuarioId));
  } catch (e) {
    console.error("[reconhecimento-facial] não consegui limpar o localStorage:", e);
  }
}

// Média de várias amostras (várias capturas do cadastro) num único
// descritor — reduz ruído de uma captura só.
export function mediaDescritores(amostras: Float32Array[]): Float32Array {
  const tamanho = amostras[0].length;
  const media = new Float32Array(tamanho);
  for (const amostra of amostras) {
    for (let i = 0; i < tamanho; i++) media[i] += amostra[i] / amostras.length;
  }
  return media;
}
