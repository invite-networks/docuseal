<h1 align="center">DocuSeal</h1>

<h3 align="center">
  Expanded self-hosted document signing with Microsoft 365 integration
</h3>

DocuSeal is an open source platform for creating, sending, filling, and signing digital documents. This repository is an independently maintained fork created to extend the self-hosted edition with selected advanced workflow features and a Microsoft 365-first integration model.

> [!IMPORTANT]
> This fork is under active development. Fork-specific features will be documented as they become available and should be evaluated carefully before production use. This project is not affiliated with or endorsed by DocuSeal LLC.

## Why This Fork Exists

The upstream project provides a strong foundation for self-hosted electronic signatures. This fork exists to build a broader open source feature set for organizations that need more control over deployment, identity, communications, and document workflows.

Authentication and email delivery use Microsoft 365. Microsoft Entra ID provides single sign-on, and Microsoft Graph sends each message through the responsible user's mailbox without stored SMTP credentials.

## Project Direction

Development is focused on two areas.

### Expanded Self-Hosted Features

- Granular user roles and permissions
- Organization branding and white-label options
- Automated reminders for pending signatures
- Conditional fields and formulas
- Bulk sending and recipient import
- Single sign-on
- Expanded template and embedded workflow capabilities

### Microsoft 365 Integration

- Transactional email and signing notifications through Microsoft Graph
- Single-tenant OpenID Connect authentication through Microsoft Entra ID
- Tenant-aware administration and configuration
- Microsoft 365 aligned identity and access controls
- Delegated email delivery without standalone SMTP infrastructure

The roadmap may evolve as features are implemented and tested. Items in this section describe the intended direction and should not be treated as completed functionality.

## Current DocuSeal Foundation

This fork retains the core capabilities provided by the upstream open source project:

- Visual PDF form builder
- Signature, initials, date, text, file, checkbox, and other field types
- Multiple submitters per document
- Automatic PDF electronic signatures
- PDF signature verification
- Mobile-optimized signing workflows
- Multilingual administration and signing experiences
- API and webhook integrations
- Storage on disk or compatible cloud object storage
- SQLite, PostgreSQL, and MySQL database support

## Project Status

The repository currently tracks the upstream DocuSeal codebase while fork-specific functionality is being developed. The included Compose configuration builds the application directly from this repository so local changes are included in the deployed container.

Release notes will identify which extended features are complete, their configuration requirements, and any migration considerations.

## Deployment

Docker Compose is the supported deployment approach. The included [`docker-compose.yml`](./docker-compose.yml) provisions the application, PostgreSQL, and Caddy with bind-mounted storage.

### Required `.env` Variables

Copy [`.env.example`](./.env.example) to `.env` in the repository root and fill in every value before starting the Compose stack:

```dotenv
# Public hostname only. Do not include https:// or a trailing slash.
HOST=sign.example.com

# Microsoft Entra tenant and App registration values.
MICROSOFT_TENANT_ID=00000000-0000-0000-0000-000000000000
MICROSOFT_CLIENT_ID=00000000-0000-0000-0000-000000000000
MICROSOFT_CLIENT_SECRET=replace-with-client-secret-value

# PostgreSQL credentials shared by the database and application containers.
POSTGRES_USER=docuseal
POSTGRES_PASSWORD=replace-with-a-long-random-password
POSTGRES_DB=docuseal
```

| Variable | Required | Description |
| --- | --- | --- |
| `HOST` | Yes | Public hostname used for HTTPS, generated links, and Microsoft callback URLs. Enter a hostname such as `sign.example.com`, without a URL scheme or path. |
| `MICROSOFT_TENANT_ID` | Yes | Directory tenant ID from Microsoft Entra ID. This application uses single-tenant authentication. |
| `MICROSOFT_CLIENT_ID` | Yes | Application (client) ID from the Microsoft Entra App registration. |
| `MICROSOFT_CLIENT_SECRET` | Yes | Client secret **value** from the App registration, not the secret ID. Rotate it before its configured expiration date. |
| `POSTGRES_USER` | No | Database role. Defaults to `docuseal`. |
| `POSTGRES_PASSWORD` | Yes | Database password. Compose refuses to start without it. |
| `POSTGRES_DB` | No | Database name. Defaults to `docuseal`. |

The `.env` file is excluded from Git and must not be committed. Restrict access to the file because the Microsoft client secret allows the application to participate in the OAuth authorization flow. The Compose configuration derives `FORCE_SSL` from `HOST`, so HTTPS enforcement, HSTS, secure cookies, and Host header validation are always on for the standard deployment. The application refuses to boot in production if `FORCE_SSL` or `ENCRYPTION_SECRET` is missing rather than silently running without them.

### Application Secrets and Data Directory

On first boot the application writes `docuseal.env` into the bind-mounted data directory (`./docuseal`) containing a generated `SECRET_KEY_BASE` and an independent `ENCRYPTION_SECRET`. The session signing key and the encryption-at-rest key are never derived from each other. To supply your own values, set both variables in the container environment instead.

The container runs as the unprivileged user `1001:1001`. On Linux hosts, give that user ownership of the data directory before the first start:

```sh
mkdir -p docuseal && sudo chown -R 1001:1001 docuseal
```

Docker Desktop on macOS and Windows maps bind-mount ownership automatically and needs no extra step.

Start or update the complete stack with:

```sh
docker compose up -d --build
```

The default configuration expects TLS to be terminated by Caddy. Deployments behind an existing reverse proxy should update the Compose environment and proxy configuration for their infrastructure.

## Microsoft Entra Configuration

Create a single-tenant App registration using a descriptive name for the deployment, such as `Document Signing`. The App registration automatically creates a related Enterprise Application in the tenant.

Under **Authentication**, add a **Web** platform. Register callback and sign-out URLs using the public hostname from `HOST`:

- `https://sign.example.com/auth/microsoft/callback`
- `https://sign.example.com/auth/microsoft/signed-out`

Configure `https://sign.example.com/auth/microsoft/frontchannel-logout` as the front-channel logout URL. Replace `sign.example.com` with the deployment's actual hostname. Every environment needs URLs matching its externally visible hostname. Separate App registrations are recommended for production and staging because an App registration supports only one front-channel logout URL.

Create a client secret under **Certificates & secrets** and place its secret value in `MICROSOFT_CLIENT_SECRET`. The application uses the OAuth 2.0 authorization code flow with PKCE and stores each user's delegated access and refresh tokens using Active Record encryption.

### Microsoft Graph Permissions

Add these delegated Microsoft Graph permissions and grant tenant-wide administrator consent:

- `openid`
- `profile`
- `email`
- `offline_access`
- `User.Read`
- `Mail.Send`

`User.Read` allows the application to synchronize the signed-in user's profile. Delegated `Mail.Send` allows the application to send signing messages as that signed-in user. Do not grant the Microsoft Graph **Application** version of `Mail.Send`; this application requests and uses the delegated permission.

### App Roles

Create the following App roles under **App registrations > App roles**. Set **Allowed member types** to `Users/Groups` and enable each role.

| Display name | Value | Application access |
| --- | --- | --- |
| `Admin` | `admin` | Full access to account settings, users, templates, submissions, and signed documents. |
| `User` | `user` | Can create and manage only their own templates and submissions. |
| `Auditor` | `auditor` | Read-only access to templates and all completed submissions and signed documents. Incomplete submissions are not accessible. |

In the Enterprise Application, set **Assignment required** to **Yes**, then assign the appropriate users or groups. App role assignments are included in the Entra ID token and synchronized at every sign-in.

If a user has no recognized App role, the application assigns the standard `user` role. If more than one recognized role is present, precedence is `admin`, then `auditor`, then `user`. Assign at least one person or group to `Admin` before relying on Entra-managed access.

The role values are application identifiers and must be entered exactly as lowercase `admin`, `user`, and `auditor`. Display names may be localized or adapted to an organization's naming conventions.

### User Provisioning and Email Delivery

The application synchronizes each user's first name, last name, email address, title, and company from Microsoft 365 at every sign-in. Title and company remain blank when those values are not set in Entra ID.

Users are identified by the immutable Entra tenant and object IDs only. Email addresses are never used to attach a Microsoft login to an existing local record, so a reassigned mailbox cannot inherit another person's DocuSeal history. Anyone who can sign in through the Enterprise Application is provisioned automatically on first login; control who has access with **Assignment required** and role assignments in Entra ID. Removing or disabling a person is also done in Entra ID.

Local passwords do not exist. The Devise password, lockable, recoverable, and TOTP columns were removed from the `users` table.

Signing invitations contain secure signing links. Completion notices contain secure links for reviewing and downloading completed documents. Email attachments and SMTP fallback are not supported.

## Contributing

Bug reports, feature proposals, documentation improvements, and code contributions are welcome. Please [open an issue](../../issues) before beginning a substantial change so the proposed work can be aligned with the roadmap.

Contributions should clearly distinguish between upstream fixes and fork-specific behavior. Changes that may also benefit the original project should be considered for submission upstream.

### Running the Tests

The test suite runs inside a standalone Compose stack so no local Ruby toolchain is required:

```sh
docker compose -f docker-compose.test.yml build test
docker compose -f docker-compose.test.yml run --rm test bundle exec rake db:create db:migrate
docker compose -f docker-compose.test.yml run --rm test bundle exec rspec
docker compose -f docker-compose.test.yml run --rm test bundle exec rubocop
```

DocuSeal is a trademark of its respective owner. This fork preserves the attribution required by the upstream license and additional terms.

## License

This project is distributed under the GNU Affero General Public License v3.0 with the upstream Section 7(b) additional terms. See [`LICENSE`](./LICENSE) and [`LICENSE_ADDITIONAL_TERMS`](./LICENSE_ADDITIONAL_TERMS) for details.

Unless otherwise noted, original files are Copyright 2023-2026 DocuSeal LLC. Modifications made in this fork are also distributed under the same license terms.
