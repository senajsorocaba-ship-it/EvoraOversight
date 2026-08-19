import type { Metadata } from "next";
import "@/styles/evora-painel.css";

export const metadata: Metadata = {
  title: "Évora Oversight",
  description: "Painel do Gabinete — Évora Oversight",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
