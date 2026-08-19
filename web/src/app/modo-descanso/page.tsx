import Link from "next/link";

export default function ModoDescansoPage() {
  return (
    <>
      <div className="watermark" />
      <Link href="/" className="rest show" id="rest" style={{ position: "static", color: "inherit" }}>
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
          <div className="rcard"><b>Template protegido</b><span>Biometria cifrada no AEGIS · processamento local (LGPD).</span></div>
        </div>
        <div className="foot">🔒 Évora Oversight · Regra 03 — sigilo físico sem perder o trabalho</div>
      </Link>
    </>
  );
}
