# React / Angular / TypeScript

## Conventions
- TypeScript `strict` on. No `any` without a comment explaining why; prefer `unknown` + narrowing.
- Follow the project's framework patterns:
  - **React**: function components + hooks; server state via the project's library (TanStack Query, SWR, RTK Query); keep components small.
  - **Angular**: standalone components, signals where the project uses them, services for data access, `OnPush` change detection, RxJS subscriptions cleaned up (`takeUntilDestroyed` / `async` pipe).
- API types generated from OpenAPI where available, not hand-copied.
- Environment config through the build system; never commit real keys to `.env` files.
- Accessibility: semantic HTML, labels on inputs, keyboard navigation, visible focus.

## Testing
- Unit/component: Jest or Vitest + Testing Library (React); Jasmine/Karma or Jest (Angular) as the project uses.
- E2E: Playwright or Cypress for critical flows only.
- Commands: `npm test`, `npm run lint`, `npm run build` (or `npx ng test --watch=false`).

## Security
- No `dangerouslySetInnerHTML` / `bypassSecurityTrust*` with untrusted content; sanitize if unavoidable.
- Tokens: prefer httpOnly secure cookies over `localStorage`; follow the project's auth library (MSAL, etc.).
- Never put secrets in front-end code or public env vars (`NEXT_PUBLIC_`, `VITE_`, `environment.ts`): they ship to the browser.
- CSP headers; validate redirects (no open redirects).
- `npm audit --omit=dev` before release; pin dependencies with a lockfile.

## Cost & performance
- Code-split routes; lazy-load heavy components; memoize only where profiling shows a need.
- Avoid request waterfalls; cache and dedupe server calls.
