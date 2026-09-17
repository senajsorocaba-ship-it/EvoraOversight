import type { NextConfig } from "next";

// Cabeçalhos de segurança — a parte que o Caderno do Programador (Manual
// v11.0) já sinalizou como "depende da hospedagem": Next.js/Vercel não
// manda nenhum por padrão. Aplicados a toda rota (`source: "/(.*)"`).
//
// Deliberadamente SEM Content-Security-Policy aqui: a CSP certa depende
// de testar ao vivo no navegador (Supabase, a própria API da Claude via
// /api/bia — chamada server-side, não do navegador —, o modelo do
// face-api carregado de /models, o microfone/câmera da Bia e do
// reconhecimento facial) — uma CSP errada quebra a aplicação em vez de
// protegê-la, e não dá pra validar isso sem navegador real. Fica como
// próximo passo, depois do primeiro deploy, testado ao vivo.
const HEADERS_SEGURANCA = [
  // Nunca deixa a aplicação ser embutida num <iframe> de outro site —
  // fecha clickjacking. "DENY", não "SAMEORIGIN": nada aqui precisa se
  // auto-embutir.
  { key: "X-Frame-Options", value: "DENY" },
  // Navegador não tenta "adivinhar" o tipo de um arquivo a partir do
  // conteúdo — fecha um vetor clássico de MIME-sniffing.
  { key: "X-Content-Type-Options", value: "nosniff" },
  // Não manda a URL completa de origem pra terceiros em navegação
  // cross-site; manda só a origem. Protocolos/URLs internas (ex.:
  // /demandas/552) não vazam no header Referer de saída.
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  // Câmera/microfone só pra este mesmo site (Bia por voz e o
  // reconhecimento facial do modo-descanso usam os dois) — nunca pra um
  // iframe de terceiro embutido aqui. Geolocalização/pagamento: nada
  // deste projeto usa, fecha explicitamente.
  {
    key: "Permissions-Policy",
    value: "camera=(self), microphone=(self), geolocation=(), payment=()",
  },
  // Força HTTPS por 2 anos, incluindo subdomínios — só tem efeito real
  // atrás de HTTPS (Vercel já serve assim por padrão); inofensivo em dev
  // local (http://localhost não aplica HSTS).
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains",
  },
];

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: HEADERS_SEGURANCA,
      },
    ];
  },
};

export default nextConfig;
