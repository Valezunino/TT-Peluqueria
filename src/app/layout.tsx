import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "TT Peluquería · Tu próximo corte", description: "Reservá tu corte en TT Peluquería. Dardo Rocha 626, Rojas. Atención personalizada de martes a sábado." };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="es-AR"><body>{children}</body></html> }
