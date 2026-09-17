import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

// Next.js 16 renomeou middleware.ts -> proxy.ts (função + convenção de
// arquivo, mesmo comportamento — ver node_modules/next/dist/docs/.../
// proxy.md). Este arquivo é o que FALTAVA: o helper updateSession() já
// existia em lib/supabase/middleware.ts, pronto e correto (getUser(),
// não getSession() — revalida contra o servidor, não confia só no
// cookie), mas nunca era chamado por nada. Sem isto, toda rota do
// dashboard ficava alcançável por URL sem sessão nenhuma (RLS ainda
// bloqueava o DADO, mas a casca da tela abria).
//
// A RLS continua sendo a trava de verdade (ver evora_rls_mvp_v1.sql) —
// isto aqui é só a primeira linha de defesa, no nível de rota. Server
// Functions (`"use server"`) NÃO são cobertas pelo matcher da mesma
// forma que páginas — cada rota que lida com dado sensível já valida a
// própria sessão server-side (ver web/src/app/api/bia/route.ts), não
// depende só disto.
export function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: [
    // Roda em toda rota, exceto:
    // - /api/*        — cada rota já valida sessão internamente e devolve
    //                    401 em JSON; redirecionar pra /login quebraria isso.
    // - _next/static, _next/image — assets do Next, nunca precisam de sessão.
    // - /models/*.bin+.json — pesos do face-api (reconhecimento facial,
    //   public/models/) — precisam carregar mesmo no instante da própria
    //   trava por rosto (modo-descanso), sem depender do proxy revalidar
    //   sessão a cada arquivo de peso.
    // - arquivos estáticos óbvios (favicon, imagens).
    "/((?!api|_next/static|_next/image|models/|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|webp|ico|json|bin)$).*)",
  ],
};
