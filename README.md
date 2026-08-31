<h1 align="center">DocuSeal</h1>

<h3 align="center">
  Expanded self-hosted document signing with Microsoft 365 integration
</h3>

DocuSeal is an open source platform for creating, sending, filling, and signing digital documents. This repository is an independently maintained fork created to extend the self-hosted edition with selected advanced workflow features and a Microsoft 365-first integration model.

> [!IMPORTANT]
> This fork is under active development. Fork-specific features will be documented as they become available and should be evaluated carefully before production use. This project is not affiliated with or endorsed by DocuSeal LLC.

## Why This Fork Exists

The upstream project provides a strong foundation for self-hosted electronic signatures. This fork exists to build a broader open source feature set for organizations that need more control over deployment, identity, communications, and document workflows.

The project is also moving away from direct SMTP as its primary notification path. Microsoft Graph and Microsoft Entra ID will provide modern authentication and Microsoft 365-based message delivery without requiring stored SMTP credentials.

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
- OAuth-based application authentication through Microsoft Entra ID
- Tenant-aware administration and configuration
- Microsoft 365 aligned identity and access controls
- Reduced dependence on standalone SMTP infrastructure

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

```sh
HOST=sign.example.com docker compose up -d --build
```

The default configuration expects TLS to be terminated by Caddy. Deployments behind an existing reverse proxy should update the Compose environment and proxy configuration for their infrastructure.

## Contributing

Bug reports, feature proposals, documentation improvements, and code contributions are welcome. Please [open an issue](../../issues) before beginning a substantial change so the proposed work can be aligned with the roadmap.

Contributions should clearly distinguish between upstream fixes and fork-specific behavior. Changes that may also benefit the original project should be considered for submission upstream.

DocuSeal is a trademark of its respective owner. This fork preserves the attribution required by the upstream license and additional terms.

## License

This project is distributed under the GNU Affero General Public License v3.0 with the upstream Section 7(b) additional terms. See [`LICENSE`](./LICENSE) and [`LICENSE_ADDITIONAL_TERMS`](./LICENSE_ADDITIONAL_TERMS) for details.

Unless otherwise noted, original files are Copyright 2023-2026 DocuSeal LLC. Modifications made in this fork are also distributed under the same license terms.
