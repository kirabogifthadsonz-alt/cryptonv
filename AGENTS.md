<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

- The CRYPTONVA app (migrated from Manus) is served verbatim: `/` returns src/legacy/index.html.txt from a server handler, with public/app.js and public/app.css. Why: the user requires the UI to stay exactly as built.

- CN allocations use a separate read-only user reward ledger and a signup trigger, never the cash ledger; this prevents pre-launch rewards becoming spendable funds.
- CN launch eligibility requires both persisted launch milestones; absent status defaults to locked to prevent premature withdrawal.
- CN wallet presentation is scoped to the CN view with its own semantic CSS tokens; other legacy screens retain their existing styles and financial wiring.
- External Vercel deployments use Nitro's Vercel preset and forward public API paths to the published Lovable service, while asset paths use the Lovable asset host; this preserves managed financial credentials and the unchanged legacy UI without exporting privileged keys.
- CN artwork is served from checked-in public/public/assets files, not CDN pointers; this keeps the original images portable with source ZIP exports like the home logo.
- Local-currency display estimates load the public USD reference feed independently of persisted payment FX rates; this keeps current display values from altering financial settlement.
