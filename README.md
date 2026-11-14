# ns8-suitecrm

Module id: `suitecrm`. Images are pinned in `build-images.sh` and updated through reviewed changes.

## Install

```bash
add-module ghcr.io/geniusdynamics/suitecrm:latest 1
```

The command returns the instance id, for example `suitecrm1`. Use the id NS8 returns.

## Configure

```bash
api-cli run configure-module --agent module/suitecrm1 --data - <<'EOF'
{
  "host": "suitecrm.example.org",
  "http2https": true,
  "lets_encrypt": false
}
EOF
```

| Parameter | Required | Type | Description |
|---|---|---|---|
| `host` | yes | string | Host name for the application, like 'suitecrm.domain.org' |
| `lets_encrypt` | yes | boolean | Request a valid Let's Encrypt certificate. |
| `http2https` | yes | boolean | Redirect all the HTTP requests to HTTPS |

## Configuration output

`get-configuration` returns: `host`, `lets_encrypt`, `http2https`.

## Images

| Image | Version |
|---|---|
| `docker.io/mariadb` | `11.4.13` |
| `ghcr.io/geniusdynamics/suitecrm-app` | SuiteCRM `8.10.2` on `docker.io/library/php:8.3.36-apache`, built from `suitecrm/Containerfile` |

No maintained official SuiteCRM image exists, and `docker.io/bitnamilegacy/suitecrm`
no longer gets updates, so the module builds its own application image from the
official SuiteCRM release archive. On the first start the image copies SuiteCRM into
the `suitecrm-data` volume and installs it; the `admin` password is in
`state/secrets.env`. A newer image does not replace the code in the volume: upgrade
SuiteCRM with its own upgrade procedure.

## Network and access

- Reserves 1 TCP port(s) on the node. The web application is published through Traefik on the configured host name.
- Runs rootless.
- Declares these NS8 authorizations: `traefik@node:routeadm`.

## Backup

The following paths are included in the NS8 backup (`imageroot/etc/state-include.conf`):

- `state/secrets.env`
- `state/suitecrm.sql`
- `volumes/suitecrm-data`

## Services

- `mariadb-app.service`
- `suitecrm-app.service`
- `suitecrm.service`

## Get the configuration

```bash
api-cli run get-configuration --agent module/suitecrm1
```

## Update and uninstall

```bash
api-cli run update-module --data '{"module_url":"ghcr.io/geniusdynamics/suitecrm:latest","instances":["suitecrm1"],"force":true}'
remove-module --no-preserve suitecrm1
```

## Testing

Continuous integration:

- `Publish images` builds the module image on every push.
- `Test module` installs the image on a QEMU NS8 node and runs the Robot Framework suite in `tests/`. It runs after `Publish images` succeeds on `dev` and on `main`.
- `Build API JSON Schema docs` and the security scan run alongside.

The suite installs the module, configures a host name, checks that the web application answers through Traefik, takes UI screenshots and removes the module.

Run it locally with the NS8 standard infrastructure described in the [ns8-github-actions README](https://github.com/NethServer/ns8-github-actions/blob/v1/README.md#running-tests-locally).

## Open items

Found by the NS8 module standards check. These must be resolved before a stable release:

- The module description is still the template text: write a description of at least 60 characters in ui/public/metadata.json
- tests/suitecrm.robot generated from template: set real configure payload and URL check
- metadata: documentation_url is a placeholder
- metadata: categories empty (use standard categories)
- metadata: description.en needs >= 60 real chars (+ it translation)
- mariadb-app.service: uses %S/state, kickstart uses %E/state
- suitecrm-app.service: uses %S/state, kickstart uses %E/state
- suitecrm.service: uses %S/state, kickstart uses %E/state
- discover-smarthost still present: remove if the app does not use SMTP
- README still has the template boilerplate
- mariadb-app.service: %S/state changed to %E/state (review the bind mounts that remain)
- suitecrm-app.service: %S/state changed to %E/state (review the bind mounts that remain)
- suitecrm.service: %S/state changed to %E/state (review the bind mounts that remain)
- imageroot/actions/restore-module/80start_services: smarthost lines removed, check the unit still starts
- imageroot/actions/configure-module/80start_services: smarthost lines removed, check the unit still starts
- imageroot/systemd/user/suitecrm-app.service: smarthost lines removed, check the unit still starts
- SUITECRM_IMAGE is used by the module but no image in the label provides it: leftover from the template?

## Upstream

Application documentation: https://docs.suitecrm.com/

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
