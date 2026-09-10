import Anthropic from "@anthropic-ai/sdk";
import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

// Rota da Bia por voz (ver bia-voz-context.tsx) — responde perguntas com
// dado real do próprio tenant, nunca inventado (Cláusula de Caráter
// Travado, mesmo princípio de evora_motor_execucao.py:montar_prompt_sistema).
//
// Usa a SESSÃO do usuário autenticado (createClient de lib/supabase/server,
// já existente) — nunca a service_role key. RLS isola tenant/mundo
// automaticamente, exatamente como qualquer outra página já faz; esta rota
// não enxerga mais dado do que o próprio usuário já veria navegando.

const MODELO_PADRAO = "claude-sonnet-5";

type Tenant = {
  nome_autoridade: string;
  cargo: string | null;
  municipio_sede: string | null;
};

type Briefing = {
  mundo: string;
  data_referencia: string;
  markdown: string | null;
};

type Demanda = {
  titulo: string;
  tema: string | null;
  status: string;
  urgencia: number;
  prazo: string | null;
  bairro: string | null;
};

type Compromisso = {
  titulo: string;
  inicio: string;
  com_quem: string | null;
  pauta: string | null;
};

type FarusItem = {
  titulo: string;
  url: string | null;
  especie: string;
  estado: string;
  publicado_em: string | null;
};

function montarPromptSistema(tenant: Tenant) {
  const local = [tenant.municipio_sede].filter(Boolean).join(", ");
  return `Você é a Bia, Gestora do Gabinete na plataforma Évora Oversight, respondendo por VOZ a ${tenant.nome_autoridade}, ${tenant.cargo ?? "autoridade"} (${local}).

REGRAS INVIOLÁVEIS (Cláusula de Caráter Travado):
- Responda SOMENTE com base nos dados fornecidos abaixo. Nunca invente fato, número ou nome que não esteja neles.
- Se a pergunta não puder ser respondida com esses dados, diga claramente que não tem essa informação agora — nunca "preencha" com suposição.
- Nunca mencione ou infira identificação de cidadãos (protegido por LGPD) — não está nos dados de propósito.
- Resposta curta e direta (isto será falado em voz alta, não lido) — no máximo 3-4 frases.
- Tom factual, respeitoso, sem opinião pessoal.
- Fale como uma pessoa conversando, não como um robô lendo uma lista: frases curtas e naturais, conectadas ("Você tem duas demandas em aberto: uma sobre iluminação e outra sobre a praça." em vez de recitar campo por campo tipo formulário). Nunca leia JSON, colchetes ou nomes de campo em voz alta — traduza pra linguagem natural.
- Se a pergunta for sobre "essa página"/"essa tela"/"o que tem aqui" (pedir pra detalhar, ler, resumir ou descrever a tela atual), responda com base no "Conteúdo visível na tela agora" fornecido abaixo, não nos dados estruturados — é o que a pessoa está olhando neste momento. Resuma o que importa, não leia tudo literalmente palavra por palavra.
- O "Acervo FARUS do território" é o banco de informação sobre a cidade — primeira coisa a consultar quando perguntarem algo sobre o município, a prefeitura, a câmara ou notícias locais em geral. Todo item marcado "estado: nao_verificado" DEVE ser citado como ainda não verificado (ex.: "encontrei uma notícia não confirmada de que...") — nunca como fato certo. Itens sem "estado" (fontes/notícias) podem ser citados normalmente.`;
}

function montarMensagemUsuario(
  pergunta: string,
  briefings: Briefing[],
  demandas: Demanda[],
  compromissos: Compromisso[],
  farus: FarusItem[],
  paginaTitulo: string | null,
  paginaTexto: string | null
) {
  const partes = [`Pergunta falada: "${pergunta}"`, ""];

  if (paginaTexto) {
    partes.push(`Tela atual: "${paginaTitulo ?? "(sem título)"}"`);
    partes.push("Conteúdo visível na tela agora:");
    partes.push(paginaTexto);
    partes.push("");
  }

  if (briefings.length) {
    partes.push("Briefing(s) mais recente(s):");
    for (const b of briefings) {
      partes.push(`[${b.mundo}, ${b.data_referencia}] ${b.markdown ?? "(ainda sem texto redigido)"}`);
    }
  } else {
    partes.push("Nenhum briefing gerado ainda.");
  }

  partes.push("", "Demandas em aberto:");
  partes.push(
    demandas.length
      ? JSON.stringify(demandas)
      : "Nenhuma demanda em aberto no momento."
  );

  partes.push("", "Próximos compromissos:");
  partes.push(
    compromissos.length
      ? JSON.stringify(compromissos)
      : "Nenhum compromisso futuro registrado."
  );

  partes.push("", "Acervo FARUS do território (banco de informação sobre a cidade):");
  partes.push(
    farus.length
      ? JSON.stringify(farus)
      : "Nada coletado ainda para o território deste gabinete."
  );

  return partes.join("\n");
}

export async function POST(request: Request) {
  const { pergunta, paginaTitulo, paginaTexto } = (await request.json().catch(() => ({}))) as {
    pergunta?: string;
    paginaTitulo?: string | null;
    paginaTexto?: string | null;
  };
  if (!pergunta || !pergunta.trim()) {
    return NextResponse.json({ resposta: "Não entendi a pergunta." }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ resposta: "Sessão expirada — faça login de novo." }, { status: 401 });
  }

  // A busca em `usuarios` (só pra confirmar que a conta tem cadastro de
  // gabinete) e as 5 consultas de dado abaixo não dependem umas das
  // outras — nenhuma delas precisa de usuario.tenant_id, porque RLS
  // (tenants_isolamento/farus_itens_leitura/etc.) já filtra tudo pelo
  // tenant da própria sessão. Rodar tudo num Promise.all só, em vez de
  // esperar a busca de usuarios terminar antes de começar o resto, corta
  // uma volta inteira de ida-e-volta ao banco do caminho crítico.
  const [
    { data: usuario },
    { data: tenant },
    { data: briefings },
    { data: demandas },
    { data: compromissos },
    { data: farus },
  ] = await Promise.all([
    supabase.from("usuarios").select("id").eq("auth_user_id", user.id).maybeSingle(),
    // RLS (tenants_isolamento: id = evora_tenant_atual()) já restringe a
    // leitura ao próprio tenant — nenhum .eq(tenant_id) precisa ser escrito.
    supabase.from("tenants").select("nome_autoridade, cargo, municipio_sede").maybeSingle(),
    supabase
      .from("briefings")
      .select("mundo, data_referencia, markdown")
      .eq("ativo", true)
      .order("data_referencia", { ascending: false })
      .limit(4),
    supabase
      .from("demandas")
      .select("titulo, tema, status, urgencia, prazo, bairro")
      .in("status", ["registrada", "em_andamento", "aguardando_terceiro"])
      .eq("ativa", true)
      .limit(30),
    supabase
      .from("compromissos")
      .select("titulo, inicio, com_quem, pauta")
      .gte("inicio", new Date().toISOString())
      .eq("ativo", true)
      .eq("cancelado", false)
      .order("inicio", { ascending: true })
      .limit(10),
    // RLS (farus_itens_leitura) já filtra pelo território que este tenant
    // segue — nenhum filtro extra precisa ser escrito aqui.
    supabase
      .from("farus_itens")
      .select("titulo, url, especie, estado, publicado_em")
      .order("capturado_em", { ascending: false })
      .limit(20),
  ]);

  if (!usuario) {
    return NextResponse.json(
      { resposta: "Não encontrei seu cadastro de gabinete." },
      { status: 404 }
    );
  }
  if (!tenant) {
    return NextResponse.json({ resposta: "Não encontrei os dados do gabinete." }, { status: 404 });
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { resposta: "A Bia está sem acesso à API de linguagem no momento — avise o suporte." },
      { status: 503 }
    );
  }

  // Streaming: a resposta da Claude leva uns 2,5-3,5s inteira (medido) —
  // mandar texto conforme ele é gerado (em vez de esperar tudo pra só
  // então responder) é o que permite a Bia começar a falar a primeira
  // frase em menos de 1s, em vez de ficar muda até o fim. O cliente
  // (bia-voz-context.tsx) lê isto como texto puro por pedaço — sem SSE,
  // sem JSON por linha, só os caracteres saindo na ordem gerada.
  try {
    const client = new Anthropic({ apiKey });
    const encoder = new TextEncoder();

    const corpo = new ReadableStream<Uint8Array>({
      async start(controller) {
        let recebeuAlgo = false;
        const streamClaude = client.messages.stream({
          model: process.env.ANTHROPIC_MODEL_BIA_VOZ || MODELO_PADRAO,
          max_tokens: 500,
          system: montarPromptSistema(tenant as Tenant),
          output_config: { effort: "low" },
          messages: [
            {
              role: "user",
              content: montarMensagemUsuario(
                pergunta,
                (briefings ?? []) as Briefing[],
                (demandas ?? []) as Demanda[],
                (compromissos ?? []) as Compromisso[],
                (farus ?? []) as FarusItem[],
                paginaTitulo ?? null,
                paginaTexto ?? null
              ),
            },
          ],
        });

        streamClaude.on("text", (delta) => {
          recebeuAlgo = true;
          controller.enqueue(encoder.encode(delta));
        });

        try {
          await streamClaude.done();
        } catch (e) {
          // Degradação avisada DENTRO do próprio fluxo de texto — o
          // cliente não precisa entender um protocolo de erro à parte,
          // só fala o que chega, e o que chega já explica o que houve.
          console.error("[api/bia] stream da Claude falhou:", e);
          const aviso = recebeuAlgo
            ? " A ligação caiu no meio da resposta — pode ter ficado incompleta."
            : "Não consegui completar a resposta agora — o serviço de IA está indisponível.";
          controller.enqueue(encoder.encode(aviso));
        }
        controller.close();
      },
    });

    return new Response(corpo, {
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  } catch {
    return NextResponse.json(
      { resposta: "A Bia não conseguiu responder agora — o serviço de IA está indisponível." },
      { status: 502 }
    );
  }
}
