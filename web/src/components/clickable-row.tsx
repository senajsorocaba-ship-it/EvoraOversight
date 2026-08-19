"use client";

import { useRouter } from "next/navigation";
import type { ReactNode } from "react";

export function ClickableRow({
  href,
  style,
  children,
}: {
  href: string;
  style?: React.CSSProperties;
  children: ReactNode;
}) {
  const router = useRouter();
  return (
    <tr onClick={() => router.push(href)} style={{ cursor: "pointer", ...style }}>
      {children}
    </tr>
  );
}
