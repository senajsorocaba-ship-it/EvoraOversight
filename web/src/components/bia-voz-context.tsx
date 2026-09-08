"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { useRouter } from "next/navigation";
import { NAV_ITEMS } from "@/components/nav-items";

// Palavra de ativação (Manual v10.8, linha 527): a Bia só age depois de
// "Bia, ...". Fala sem esse prefixo é ignorada — nunca vira comando, nunca
// sai do navegador.
const PREFIXO = /^\s*b[ií]a[,.\s]+/i;
// Só a palavra de ativação, sem nada depois (ex.: "Bia" sozinho, com pausa
// antes do comando — muito comum na fala real: a pessoa pausa depois do
// nome). Nesse caso a Bia responde "Pode falar" e espera a PRÓXIMA fala
// final como o comando, em vez de descartar tudo em silêncio.
const SO_PREFIXO = /^\s*b[ií]a[.,!?\s]*$/i;
const TEMPO_ESPERA_COMANDO_MS = 6000;
// Achado real testando: o Chrome frequentemente fecha um resultado "final"
// no meio de uma frase natural (uma pausa curta pra respirar já basta) e
// só continua com outro resultado "final" separado logo em seguida — sem
// repetir "Bia". Despachar cada um IMEDIATAMENTE como se fosse um comando
// completo cortava a frase ao meio (ex.: "Bia, abre" virava um comando,
// "demandas" virava outro, ignorado por não ter o prefixo) — e cada
// despacho prematuro disparava sua própria chamada a /api/bia e sua
// própria fala, se atropelando (erro real visto: "speechSynthesis:
// interrupted"). Por isso todo resultado final entra num buffer e só é
// despachado depois de um período de silêncio sem novo resultado — trata a
// frase inteira como um comando só, mesmo com pausas naturais no meio.
const TEMPO_SILENCIO_FINALIZACAO_MS = 1200;

// Verbos de navegação genéricos que o Manual cita (linha 519), além dos
// rótulos de NAV_ITEMS (Demandas, Fiscalizações, Briefing, etc.).
const VOLTAR = /\b(volt(e|a|ar))\b/i;
const INICIO = /\b(in[ií]cio|come[çc]o|casa|home|vis[ãa]o geral)\b/i;

function normalizar(s: string) {
  return s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "");
}

type BiaVozState = {
  suportado: boolean;
  ligada: boolean;
  ouvindo: boolean;
  processando: boolean;
  transcricaoAoVivo: string;
  ultimoComando: string | null;
  respostaFalada: string | null;
  erro: string | null;
  ligar: () => void;
  desligar: () => void;
};

const BiaVozContext = createContext<BiaVozState | null>(null);

export function BiaVozProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [suportado] = useState(() => {
    if (typeof window === "undefined") return false;
    const w = window as unknown as {
      SpeechRecognition?: typeof SpeechRecognition;
      webkitSpeechRecognition?: typeof SpeechRecognition;
    };
    return Boolean(w.SpeechRecognition ?? w.webkitSpeechRecognition);
  });
  const [ligada, setLigada] = useState(false);
  const [ouvindo, setOuvindo] = useState(false);
  const [processando, setProcessando] = useState(false);
  const [transcricaoAoVivo, setTranscricaoAoVivo] = useState("");
  const [ultimoComando, setUltimoComando] = useState<string | null>(null);
  const [respostaFalada, setRespostaFalada] = useState<string | null>(null);
  const [erro, setErro] = useState<string | null>(null);

  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const ligadaRef = useRef(false);
  const aguardandoComandoRef = useRef(false);
  const timeoutComandoRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const vozRef = useRef<SpeechSynthesisVoice | null>(null);
  const bufferComandoRef = useRef<string | null>(null);
  const timeoutFinalizacaoRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Escolhe uma voz feminina em pt-BR explicitamente — sem isso o navegador
  // usa QUALQUER voz padrão dele (às vezes nem em português), o que soava
  // robótico/errado.
  //
  // Prioridade 1: vozes NEURAIS/online (Edge expõe vozes tipo "Microsoft
  // Francisca Online (Natural)" — geradas por rede neural, soam muito mais
  // humanas que a voz offline clássica do Windows/SAPI). Grátis, nativa do
  // navegador, sem serviço pago novo — só significa escolher a melhor
  // opção que já existe. Prioridade 2: nome feminino conhecido, mesmo
  // offline. Por último, qualquer voz em português.
  const escolherVoz = useCallback(() => {
    if (typeof window === "undefined" || !window.speechSynthesis) return null;
    const vozes = window.speechSynthesis.getVoices();
    if (!vozes.length) return null;
    const emPortugues = (v: SpeechSynthesisVoice) => v.lang.toLowerCase().startsWith("pt");
    const nomesFemininos = [
      "luciana", "maria", "francisca", "camila", "vitória", "vitoria",
      "google português do brasil", "google português", "fernanda", "leticia", "letícia",
    ];

    const neural = vozes.find(
      (v) => emPortugues(v) && /online|natural|neural/i.test(v.name)
    );
    if (neural) return neural;

    const porNomeFeminino = vozes.find(
      (v) => emPortugues(v) && nomesFemininos.some((n) => v.name.toLowerCase().includes(n))
    );
    if (porNomeFeminino) return porNomeFeminino;

    return (
      vozes.find((v) => v.lang.toLowerCase() === "pt-br") ??
      vozes.find(emPortugues) ??
      null
    );
  }, []);

  useEffect(() => {
    if (typeof window === "undefined" || !window.speechSynthesis) return;
    // Log único de diagnóstico — ajuda a ver, pelo navegador de quem
    // testar, quais vozes existem de verdade pra ajustar a lista de nomes
    // acima se precisar (o catálogo varia MUITO por sistema operacional/
    // navegador — Edge tende a ter vozes neurais melhores que Chrome).
    const vozesDisponiveis = window.speechSynthesis.getVoices();
    if (vozesDisponiveis.length) {
      console.log(
        "[Bia] vozes disponíveis neste navegador:",
        vozesDisponiveis.map((v) => `${v.name} (${v.lang}${v.localService ? ", local" : ", online"})`)
      );
    }
    vozRef.current = escolherVoz();
    const atualizar = () => {
      vozRef.current = escolherVoz();
      console.log("[Bia] voz escolhida:", vozRef.current?.name ?? "(nenhuma — padrão do navegador)");
    };
    window.speechSynthesis.addEventListener("voiceschanged", atualizar);
    return () => window.speechSynthesis.removeEventListener("voiceschanged", atualizar);
  }, [escolherVoz]);

  // Bug conhecido do Chrome: chamar speak() na mesma tarefa de um cancel()
  // (ou logo após o reconhecimento de voz devolver um resultado) às vezes
  // faz a fala ser descartada em silêncio — sem onerror, sem onstart, nada.
  // Duas defesas: (1) um pequeno atraso entre cancel() e speak(), (2) um
  // vigia que confere se onstart disparou; se não disparou a tempo, tenta
  // de novo uma vez com uma nova instância de utterance (reusar a mesma
  // depois de falhar não funciona de forma confiável nesse bug).
  // Função nomeada (não a const de fora) pra recursão seguro dentro do
  // useCallback — evita tanto "usado antes de declarado" quanto o problema
  // de reatribuir um ref durante a renderização.
  const falarDeVerdade = useCallback(function tentar(texto: string, tentativa: number) {
    if (typeof window === "undefined" || !window.speechSynthesis) return;
    const utter = new SpeechSynthesisUtterance(texto);
    utter.lang = "pt-BR";
    // Ritmo levemente mais devagar que o padrão (1.0) soa mais calmo e
    // menos "robô lendo depressa"; pitch fica no natural da própria voz
    // (1.0) — forçar um pitch artificial pra cima costuma DISTORCER a voz
    // e soar mais sintético, não menos. A naturalidade real vem de
    // escolher uma voz melhor (ver escolherVoz acima), não de mexer no
    // tom por cima dela.
    utter.rate = 0.96;
    utter.pitch = 1;
    if (vozRef.current) utter.voice = vozRef.current;
    let comecou = false;
    utter.onstart = () => {
      comecou = true;
      console.log("[Bia] começou a falar. (tentativa", tentativa, ")");
    };
    utter.onend = () => console.log("[Bia] terminou de falar.");
    utter.onerror = (ev) => {
      console.error("[Bia] erro no speechSynthesis:", ev.error, "(tentativa", tentativa, ")");
      // "interrupted"/"canceled" é o cancel() de uma fala MAIS NOVA cortando
      // esta — comportamento esperado (a resposta mais recente tem
      // prioridade), não uma falha de verdade. Sem isso, cada resposta nova
      // fazia a anterior "falhar" e tentar de novo, competindo consigo
      // mesma e às vezes gerando um aviso de erro falso na tela.
      if (ev.error === "interrupted" || ev.error === "canceled") return;
      if (tentativa === 1) {
        setTimeout(() => tentar(texto, 2), 150);
      } else {
        setErro("Não consegui falar a resposta em voz alta agora.");
      }
    };
    window.speechSynthesis.speak(utter);
    console.log("[Bia] speak() chamado (tentativa", tentativa, "), voz:", vozRef.current?.name ?? "(padrão do navegador)");
    setTimeout(() => {
      if (!comecou && tentativa === 1) {
        console.warn("[Bia] speak() não iniciou em 1.2s — provável bug de silêncio do Chrome, tentando de novo.");
        window.speechSynthesis.cancel();
        tentar(texto, 2);
      } else if (!comecou && tentativa === 2) {
        console.error("[Bia] speak() falhou nas duas tentativas — desistindo, mas avisando na tela.");
        setErro("Não consegui falar a resposta em voz alta agora (o navegador não respondeu).");
      }
    }, 1200);
  }, []);

  const falar = useCallback(
    (texto: string) => {
      console.log("[Bia] falar():", texto);
      if (typeof window === "undefined" || !window.speechSynthesis || !texto) {
        console.warn("[Bia] falar() abortado — speechSynthesis indisponível ou texto vazio.");
        return;
      }
      // Cancela qualquer fala pendente antes de começar — evita fila presa
      // que parecia "não responder nada" quando na verdade só estava atrás
      // de outra fala na fila. O atraso depois do cancel() é a defesa (1)
      // acima — dar a chance do motor de síntese realmente esvaziar a fila
      // antes de mandar a próxima fala.
      window.speechSynthesis.cancel();
      setTimeout(() => falarDeVerdade(texto, 1), 50);
    },
    [falarDeVerdade]
  );

  // Toda resposta da Bia passa por aqui — SEMPRE mostra o texto na tela E
  // fala, nunca só uma das duas. Isso é o que corrige "ouve mas não traz
  // nada": antes, um comando de navegação só chamava falar() — se a síntese
  // de voz falhasse (silenciosamente, sem erro, um bug real do Chrome), não
  // sobrava nenhum sinal na tela de que algo aconteceu.
  const responder = useCallback(
    (texto: string) => {
      setRespostaFalada(texto);
      falar(texto);
    },
    [falar]
  );

  const despachar = useCallback(
    async (comando: string) => {
      const alvo = normalizar(comando);

      if (VOLTAR.test(alvo) && INICIO.test(alvo)) {
        setUltimoComando(comando);
        router.push("/");
        responder("Voltando ao início.");
        return;
      }
      if (VOLTAR.test(alvo)) {
        setUltimoComando(comando);
        router.back();
        responder("Voltando.");
        return;
      }
      if (INICIO.test(alvo)) {
        setUltimoComando(comando);
        router.push("/");
        responder("Abrindo Visão Geral.");
        return;
      }

      const item = NAV_ITEMS.find((n) => alvo.includes(normalizar(n.label)));
      if (item) {
        setUltimoComando(comando);
        router.push(item.href);
        responder(`Abrindo ${item.label}.`);
        return;
      }

      // Não é navegação — vira pergunta pra Bia responder com dado real.
      // Manda junto o texto visível da própria página atual — é o que
      // faz "Bia, detalha isso"/"fale o que tem aqui" funcionar em
      // qualquer tela, sem precisar adivinhar de antemão toda variação de
      // frase que pede pra "ler a página" (o seletor `main.content` é o
      // mesmo em toda página do dashboard — conferido).
      const areaConteudo = document.querySelector("main.content") as HTMLElement | null;
      const paginaTexto = areaConteudo?.innerText?.trim().slice(0, 6000) || null;
      const paginaTitulo = document.title || null;
      console.log(
        "[Bia] não bateu como navegação, indo pra /api/bia com:",
        comando,
        "| texto da página capturado:",
        paginaTexto ? `${paginaTexto.length} caracteres` : "(nenhum)"
      );
      setUltimoComando(comando);
      setProcessando(true);
      setRespostaFalada(null);
      try {
        const r = await fetch("/api/bia", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ pergunta: comando, paginaTitulo, paginaTexto }),
        });
        console.log("[Bia] /api/bia respondeu, status:", r.status);
        const dados = await r.json().catch((e) => {
          console.error("[Bia] resposta de /api/bia não é JSON válido:", e);
          return null;
        });
        console.log("[Bia] corpo da resposta:", dados);
        const resposta =
          dados?.resposta ||
          "Não consegui responder agora — o serviço da Bia está indisponível.";
        responder(resposta);
      } catch (e) {
        console.error("[Bia] fetch pra /api/bia falhou:", e);
        responder("Não consegui falar com o servidor agora. Tente de novo em instantes.");
      } finally {
        setProcessando(false);
      }
    },
    [router, responder]
  );

  const cancelarEspera = useCallback(() => {
    aguardandoComandoRef.current = false;
    if (timeoutComandoRef.current) {
      clearTimeout(timeoutComandoRef.current);
      timeoutComandoRef.current = null;
    }
  }, []);

  const entrarEmEspera = useCallback(() => {
    aguardandoComandoRef.current = true;
    falar("Pode falar.");
    if (timeoutComandoRef.current) clearTimeout(timeoutComandoRef.current);
    timeoutComandoRef.current = setTimeout(() => {
      if (aguardandoComandoRef.current) {
        aguardandoComandoRef.current = false;
        falar("Não entendi, pode repetir dizendo 'Bia' de novo?");
      }
    }, TEMPO_ESPERA_COMANDO_MS);
  }, [falar]);

  // Acumula um fragmento de fala no buffer do comando em andamento e
  // (re)inicia o relógio de silêncio — só quando ele chega ao fim sem
  // nenhum fragmento novo é que o comando é considerado completo e
  // despachado de uma vez só (ver comentário de TEMPO_SILENCIO_FINALIZACAO_MS).
  const acumularFragmento = useCallback(
    (fragmento: string, continuar: boolean) => {
      const anterior = continuar ? bufferComandoRef.current : null;
      const acumulado = anterior ? `${anterior} ${fragmento}`.trim() : fragmento;
      bufferComandoRef.current = acumulado;
      setUltimoComando(acumulado); // transparência: mostra o que já entendeu, ainda acumulando
      console.log("[Bia] buffer do comando agora:", JSON.stringify(acumulado));
      if (timeoutFinalizacaoRef.current) clearTimeout(timeoutFinalizacaoRef.current);
      timeoutFinalizacaoRef.current = setTimeout(() => {
        const comandoCompleto = bufferComandoRef.current;
        bufferComandoRef.current = null;
        timeoutFinalizacaoRef.current = null;
        if (comandoCompleto) {
          console.log("[Bia] silêncio suficiente — despachando comando completo:", comandoCompleto);
          despachar(comandoCompleto);
        }
      }, TEMPO_SILENCIO_FINALIZACAO_MS);
    },
    [despachar]
  );

  const onresult = useCallback(
    (ev: SpeechRecognitionEvent) => {
      let interina = "";
      for (let i = ev.resultIndex; i < ev.results.length; i++) {
        const resultado = ev.results[i];
        const texto = resultado[0].transcript;
        console.log(
          `[Bia] reconhecido (${resultado.isFinal ? "final" : "parcial"}):`,
          JSON.stringify(texto)
        );
        if (!resultado.isFinal) {
          interina += texto;
          continue;
        }

        // Já disse "Bia" numa fala anterior e está esperando o comando —
        // a próxima fala é o começo do comando, não precisa repetir "Bia".
        if (aguardandoComandoRef.current) {
          console.log("[Bia] estava esperando comando — começando a acumular:", texto);
          cancelarEspera();
          setTranscricaoAoVivo("");
          const comeco = texto.trim();
          if (comeco) acumularFragmento(comeco, false);
          continue;
        }

        // Já tem um comando em andamento (a pessoa continuou falando
        // depois de uma pausa curta) — junta ao que já foi dito, sem
        // precisar repetir "Bia" de novo.
        if (bufferComandoRef.current !== null) {
          console.log("[Bia] continuação do comando em andamento:", texto);
          setTranscricaoAoVivo("");
          if (texto.trim()) acumularFragmento(texto.trim(), true);
          continue;
        }

        if (SO_PREFIXO.test(texto)) {
          console.log("[Bia] só a palavra de ativação — entrando em espera.");
          setTranscricaoAoVivo("");
          entrarEmEspera();
          continue;
        }

        if (PREFIXO.test(texto)) {
          const comando = texto.replace(PREFIXO, "").trim();
          console.log("[Bia] comando extraído, começando a acumular:", comando);
          setTranscricaoAoVivo("");
          if (comando) acumularFragmento(comando, false);
        } else {
          console.log("[Bia] ignorado — não começa com a palavra de ativação.");
        }
      }
      setTranscricaoAoVivo(interina);
    },
    [acumularFragmento, cancelarEspera, entrarEmEspera]
  );

  const ligar = useCallback(() => {
    if (!suportado) {
      setErro("Reconhecimento de voz não é suportado neste navegador — use Chrome ou Edge.");
      return;
    }
    const Ctor =
      (window as unknown as { SpeechRecognition?: typeof SpeechRecognition })
        .SpeechRecognition ??
      (window as unknown as { webkitSpeechRecognition?: typeof SpeechRecognition })
        .webkitSpeechRecognition!;

    const recognition = new Ctor();
    recognition.lang = "pt-BR";
    recognition.continuous = true;
    recognition.interimResults = true;

    recognition.onresult = onresult;
    recognition.onstart = () => {
      console.log("[Bia] reconhecimento iniciado — ouvindo.");
      setOuvindo(true);
    };
    recognition.onerror = (ev: SpeechRecognitionErrorEvent) => {
      console.error("[Bia] erro no reconhecimento:", ev.error);
      if (ev.error === "not-allowed" || ev.error === "service-not-allowed") {
        setErro("Permissão de microfone negada — a Bia não pode ouvir sem ela.");
        ligadaRef.current = false;
        setLigada(false);
        setOuvindo(false);
      }
      // outros erros (ex.: "no-speech", "network") são tratados no onend,
      // que reinicia sozinho enquanto ligada — degradação avisada, não silenciosa.
    };
    recognition.onend = () => {
      console.log("[Bia] reconhecimento parou. ligada?", ligadaRef.current);
      setOuvindo(false);
      if (ligadaRef.current) {
        setTimeout(() => {
          if (ligadaRef.current) {
            console.log("[Bia] reiniciando reconhecimento.");
            recognition.start();
          }
        }, 300);
      }
    };

    recognitionRef.current = recognition;
    ligadaRef.current = true;
    setLigada(true);
    setErro(null);
    console.log("[Bia] chamando recognition.start() — o navegador deve pedir permissão de microfone agora, se ainda não pediu.");
    recognition.start();
  }, [suportado, onresult]);

  const desligar = useCallback(() => {
    ligadaRef.current = false;
    setLigada(false);
    setOuvindo(false);
    setTranscricaoAoVivo("");
    cancelarEspera();
    bufferComandoRef.current = null;
    if (timeoutFinalizacaoRef.current) {
      clearTimeout(timeoutFinalizacaoRef.current);
      timeoutFinalizacaoRef.current = null;
    }
    recognitionRef.current?.stop();
    recognitionRef.current = null;
  }, [cancelarEspera]);

  useEffect(() => {
    return () => {
      ligadaRef.current = false;
      if (timeoutComandoRef.current) clearTimeout(timeoutComandoRef.current);
      if (timeoutFinalizacaoRef.current) clearTimeout(timeoutFinalizacaoRef.current);
      recognitionRef.current?.stop();
    };
  }, []);

  return (
    <BiaVozContext.Provider
      value={{
        suportado,
        ligada,
        ouvindo,
        processando,
        transcricaoAoVivo,
        ultimoComando,
        respostaFalada,
        erro,
        ligar,
        desligar,
      }}
    >
      {children}
    </BiaVozContext.Provider>
  );
}

export function useBiaVoz() {
  const ctx = useContext(BiaVozContext);
  if (!ctx) throw new Error("useBiaVoz precisa estar dentro de BiaVozProvider");
  return ctx;
}
