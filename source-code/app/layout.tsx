import type {Metadata} from 'next';
import { Inter, VT323 } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-sans' });
const vt323 = VT323({ weight: '400', subsets: ['latin'], variable: '--font-vt323' });

export const metadata: Metadata = {
  title: 'HackerDeck',
  description: 'Linux/Debian game launcher UI',
};

export default function RootLayout({children}: {children: React.ReactNode}) {
  return (
    <html lang="en" className={`${inter.variable} ${vt323.variable}`}>
      <body className="font-sans antialiased bg-[#050510] text-white" suppressHydrationWarning>{children}</body>
    </html>
  );
}
