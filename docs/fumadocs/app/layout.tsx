import { Provider } from '@/components/provider';
import type { Metadata } from 'next';
import './global.css';

const metadataBase = new URL(process.env.NEXT_PUBLIC_DOCS_SITE_URL ?? 'http://localhost:4173');

export const metadata: Metadata = {
  title: {
    default: 'NginxPulse Docs',
    template: '%s | NginxPulse Docs',
  },
  description: 'NginxPulse documentation powered by Fumadocs.',
  metadataBase,
};

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <body className="min-h-screen">
        <div className="np-global-bg" aria-hidden />
        <div className="relative z-10 flex min-h-screen flex-col">
          <Provider>{children}</Provider>
        </div>
      </body>
    </html>
  );
}
