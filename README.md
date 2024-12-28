# 🏆 WordPress Template for Spin
This is a template for WordPress for Spin. It should help make spinning up new WordPress projects easier than ever.

- Different versions of PHP selectable (8.4, 8.3, 8.2)
- MariaDb

## Default configuration
To use this template, you must have [Spin](https://serversideup.net/open-source/spin/docs) installed.

```bash
spin new schnetzi/spin-template-wordpress my-wordpress-app
```

### 🌎 Default Development URLs
- **WordPress**: [https://wordpress.dev.test](https://wordpress.dev.test)
- **Mailpit**: [http://localhost:8025](http://localhost:8025)

## 👉 Required Changes Before Using This Template
> [!CAUTION]
> You need to make changes before using this template.

### Add URL to your hosts file
To be able to access the wordpress site locally you need to add the test-domain to your hosts file.
It is explained in detail in the [serversideup documentation](https://getspin.pro/docs/guide/configuring-your-hosts-file)

### Set your email contact for Let's Encrypt certificates
Let's encrypt requires an email address to issue certificates. You can set this in the Traefik configuration for production.

```yml
# File to update:
# .infrastructure/conf/traefik/prod/traefik.yml

certificatesResolvers:
  letsencryptresolver:
    acme:
      email: "changeme@example.com"
```

Change `changeme@example.com` to a valid email address. This email address will be used by Let's Encrypt to send you notifications about your certificates.

## 👨‍🔬 Advanced configuration
If you'd like to further customize your experience, here are some helpful tips:

### Trusted SSL certificates in development
We provide certificates by default. If you'd like to trust these certificates, you need to install the CA on your machine.

**Download the CA Certificate:**
- https://serversideup.net/ca/

You can create your own certificate trust if you'd like too. Just simply replace our certificates with your own.

## Project status

This project is still under development. Things that need to be done are

* [ ] Create github actions for automatic deployments

## Resources
- **[Website](https://serversideup.net/open-source/spin/)** overview of the product.
- **[Docs](https://serversideup.net/open-source/spin/docs)** for a deep-dive on how to use the product.
- **[Discord](https://serversideup.net/discord)** for friendly support from the community and the team.
- **[GitHub](https://github.com/serversideup/spin)** for source code, bug reports, and project management.
- **[Get Professional Help](https://serversideup.net/professional-support)** - Get video + screen-sharing help directly from the core contributors.

## Contributing
As an open-source project, we strive for transparency and collaboration in our development process. We greatly appreciate any contributions members of our community can provide. Whether you're fixing bugs, proposing features, improving documentation, or spreading awareness - your involvement strengthens the project. Please review our [contribution guidelines](https://serversideup.net/open-source/spin/docs/community/contributing) and [code of conduct](./.github/code_of_conduct.md) to understand how we work together respectfully.

- **Bug Report**: If you're experiencing an issue while using this project, please [create an issue](https://github.com/schnetzi/spin-template-wordpress/issues/new).
- **Feature Request**: Make this project better by [submitting a feature request](https://github.com/schnetzi/spin-template-wordpress/issues/new).
- **Documentation**: Improve our documentation by contributing to this README
- **Community Support**: Help others on [GitHub Discussions](https://github.com/serversideup/spin/discussions) or [Discord](https://serversideup.net/discord).
