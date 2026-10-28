# Changelog

Versions are git tags (`vX.Y.Z`); the images are built from the tag.

## [0.0.2] - 2026-10-28

### Security
- RCON: with `RCON_PASSWORD` unset the server used `changeme` as the RCON password, and the `.env.example` placeholder `changeme` was accepted as is. srcds runs with `-usercon` on the host network, so anyone who could reach the game port could log in to RCON with a publicly known password. An unset value or the `changeme` placeholder now leaves RCON disabled (empty `rcon_password`) and logs a warning; `setup.sh` and `make add-server` still generate a random password as before.

## [0.0.1] - 2026-10-14

### Fixed
- FastDL: docker-compose published container port 80 and the healthcheck probed port 80, but nginx listens on 8080 since the non-root change; both now use 8080.
- Dockerfile: `pipefail` for the SteamCMD `curl | tar` step so a failed download fails the build.
- Scripts: shellcheck warnings fixed (SC2155 in install-addons.sh, signal trap in wireguard/entrypoint.sh).
