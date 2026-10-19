# Cryptonva

I have built a platform using  my old lovable account and I want to continue building it from here can we migrate everything to here

This project was built with [Lovable](https://lovable.dev).

**Live app**: https://cryptonva.lovable.app

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/45273aac-87d4-425d-be2d-72e19b4bd32e).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```

## GitHub and Vercel deployment

This is a full-stack app, not a static website. Keep the existing UI and use the
included Nitro Vercel preset and `vercel.json` when importing this repository.

### Required setup

1. Publish this project on Lovable first. Its public deployment hosts the payment,
   callback, and invitation services, with the existing private credentials.
   Keep that deployment up to date when changing server code.
2. Connect GitHub in Lovable **Project settings → Git**. The editor cannot push or
   connect a repository on your behalf. Confirm the latest changes reached the
   branch you intend Vercel to deploy.
3. Import that repository into Vercel. Use **Other** as the framework, the project
   root as the root directory, and the checked-in install/build commands. Do not
   set a static `dist` output directory: Nitro emits `.vercel/output`.
4. Configure the public `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, and
   `VITE_SUPABASE_PROJECT_ID` settings from this project's existing public client
   configuration. Never add private credentials to any `VITE_*` setting.
5. Redeploy, then check sign-in, CN images, a controlled deposit, its credited
   balance, and an approved controlled withdrawal on the actual Vercel URL.

### Communication and secrets

- Browser account/data calls continue using the existing Lovable Cloud backend.
- `/api/public/*` is forwarded by Vercel to this project's stable **published**
  Lovable URL. Bearer authorization remains required by the payment handlers.
  Marz callbacks return to that hosted service, not a temporary Vercel preview.
- `/__l5e/assets-v1/*` is forwarded to the existing Lovable asset host so the supplied
  CN artwork loads without changing the screens. Other logos remain local public
  files. Do not delete the project/assets while Vercel uses them.
- Private payment and database service credentials stay in Lovable Cloud. Cloud's
  managed service-role credential is not exportable, so this setup intentionally
  does **not** run privileged financial handlers directly in Vercel.
- A completely independent deployment requires a separately owned backend,
  migration of users/data, and its own credentials; it is not achieved by Git sync.
- Password-reset and OAuth flows require the final Vercel origin to be allowed in
  the hosted authentication settings. Confirm this once the domain is available.

### Verification status

Automated checks do not transfer money. Real Marz acceptance, callback delivery,
balance crediting and payout completion must be checked with controlled transactions
after both deployments are live. Do not treat a reachable API or image as proof
that a payment completed. A provider timeout is ambiguous: never release or retry
a payout until its original reference has been reconciled.
