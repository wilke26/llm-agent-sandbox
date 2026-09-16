# LLM-Agent-Sandbox

[English version](README.md)

Dieses Repository ist eine wiederverwendbare, bewusst kleine Sandbox für LLM-Agenten mit Terminalzugriff. Sie begrenzt den möglichen Schaden, ist aber **keine** perfekte Sicherheitsgrenze. Unter nativem Linux teilen Container den Kernel; alle eingebundenen Daten müssen als für den Agenten les- und veränderbar gelten.

## Sicherheitseigenschaften

- Kein Standardweg ins Internet (`internal: true` beim Netzwerk)
- Benutzer ohne Root-Rechte (standardmäßig `10001:10001`; unter nativem Linux auf den Host-Benutzer abgebildet)
- Schreibgeschütztes Root-Dateisystem; kleine, flüchtige `tmpfs`-Mounts
- Alle Linux-Capabilities entfernt; no-new-privileges aktiviert
- Grenzen für CPU, Arbeitsspeicher, Swap, Prozesse und Dateideskriptoren
- Genau ein Bind-Mount: `./workspace` nach `/workspace`
- Kein Docker-Socket, Homeverzeichnis, Secret und kein veröffentlichter Port
- Wegwerfbarer Container und automatisierte Isolationstests
- Das gepflegte Docker-Standardprofil für Seccomp (siehe [Seccomp-Hinweise](seccomp/README.md))

## Voraussetzungen

| Plattform | Voraussetzungen und Hinweise |
|---|---|
| Linux | Docker Engine 24+ mit Compose v2. Rootless Docker oder User-Namespace-Remapping wird empfohlen. Ressourcenlimits benötigen passende cgroups-Unterstützung. |
| macOS | Aktuelles Docker Desktop mit Compose v2. Linux-Container laufen in der Docker-Desktop-VM. Die Dateifreigabe muss dieses Repository zulassen. |
| Windows | Aktuelles Docker Desktop mit WSL2-Backend und **Linux-Containern**. Für bessere Leistung in das WSL-Dateisystem klonen; bei einem Windows-Pfad die Laufwerksfreigabe zulassen. Bash-Skripte unter WSL/Git Bash oder die PowerShell-Skripte verwenden. |

Podman kann über seine Compose-Kompatibilität funktionieren, wird von dieser Vorlage aber nicht getestet.

## Build des Agenten-Images

Während der Übergangszeit unterstützt das Repository zwei Build-Wege:

- **Wolfi mit apko:** `apko` installieren und anschließend `./scripts/build-agent-image-apko.sh` ausführen. Das Skript erzeugt die ignorierte Datei `agent.apko.yaml` aus `agent.apko.yaml.tmpl`, aktualisiert `agent.apko.lock.json` und lädt `llm-agent-sandbox:local` in Docker. Änderungen der Lock-Datei wie jedes Abhängigkeitsupdate prüfen und committen. `--no-lock` nur verwenden, wenn die eingecheckte Lock-Datei bereits aktuell ist und unverändert genutzt werden soll.
- **Ubuntu-24.04-Fallback:** `dockerfiles/agent/Dockerfile` bleibt für Systeme ohne apko erhalten. Die normalen Bash- und PowerShell-Startskripte bauen diesen Fallback automatisch, jedoch nur, wenn das konfigurierte Agenten-Image lokal noch nicht vorhanden ist.

Ein bereits vorhandenes, durch `AGENT_IMAGE` benanntes Image hat Vorrang. Dadurch nutzt ein mit apko gebautes Image dieselbe Compose-Härtung und Verifikation, ohne vom Fallback überschrieben zu werden. Um den Fallback bewusst neu zu bauen, das lokale Image vorher entfernen oder `docker compose build --pull agent` ausführen.

## Schnellstart

1. `.env.example` nach `.env` kopieren und Ressourcenlimits prüfen.
2. Nur entbehrliche, nicht vertrauliche Aufgabendaten in `workspace/` ablegen.
3. Sandbox starten und prüfen:

**macOS/Linux/WSL/Git Bash**

```bash
./scripts/start.sh
./scripts/verify.sh
./scripts/shell.sh
```

**Windows PowerShell**

```powershell
./scripts/Start.ps1
./scripts/Verify.ps1
./scripts/Shell.ps1
```

Mit `./scripts/stop.sh` beziehungsweise `./scripts/Stop.ps1` stoppen und den Wegwerf-Container entfernen. Dateien im Workspace bleiben auf dem Host erhalten.

## Betriebsmodell

Der Dienst schläft lediglich dauerhaft, damit Werkzeuge sich per `docker compose exec` verbinden können. Weder `command` noch die Sicherheitsoptionen sollten leichtfertig ersetzt werden. Ein einzelner Befehl lässt sich so ausführen:

```bash
docker compose run --rm agent python3 -c 'print("Hallo aus der Sandbox")'
```

Das interne Netzwerk verhindert gewöhnlichen ausgehenden Zugriff. Werden Downloads benötigt, sollten Abhängigkeiten möglichst beim Image-Build eingebaut werden. Für kontrollierten Laufzeitzugriff ist ein separat geprüfter Proxy mit Allowlist besser als ein normales Netzwerk am Agenten. Bei jeder Egress-Freigabe erneut prüfen, ob die vorinstallierten Werkzeuge `curl` und `git` benötigt werden; beide ermöglichen direkten Abruf und Datenabfluss, sobald eine Route vorhanden ist. Keine Zugangsdaten übergeben, die der Agent nicht offenlegen darf.

## Browser-/Computer-Use-Workloads

Browserautomatisierung ist absichtlich nicht enthalten. Chromium bringt weitere Pakete, Shared-Memory-Anforderungen und ein eigenes Sandbox-Modell mit. Dafür sollte ein separates Image samt Compose-Override entstehen. Dem allgemeinen Agentendienst **kein** `SYS_ADMIN` geben. Vorzuziehen ist ein Browser-Image, das einen unprivilegierten Benutzer und die eigene Sandbox unterstützt; `/dev/shm` nur für diesen Dienst vergrößern.

## Plattformspezifische Anpassungen

- Auf SELinux-Systemen lokal `:Z` an den Workspace-Bind-Mount anhängen, falls Labels den Zugriff verhindern. Diese Änderung nicht für macOS-/Windows-Nutzer committen.
- Unter Docker Desktop gelten zusätzlich die globalen Ressourcenlimits der Desktop-Einstellungen. Es greift jeweils die niedrigere Grenze.
- Besitzrechte bei Bind-Mounts unterscheiden sich. Die feste UID/GID funktioniert direkt unter Linux; Docker Desktop übersetzt Hostzugriffe. Ist der Workspace unter Linux nicht schreibbar, `AGENT_UID` und `AGENT_GID` auf dessen Besitzer setzen und neu bauen.
- `timeout` ist nicht erforderlich: Der Container wird explizit gestoppt und ist ressourcenbeschränkt. Für ein hartes Zeitlimit in CI/Automatisierungen einen externen Job-Timeout setzen.

## Checkliste für Anpassungen

Vor zusätzlichen Paketen, Mounts, Netzwerken oder Zugangsdaten das [Bedrohungsmodell](docs/THREAT-MODEL.md) aktualisieren. Workspace eng begrenzen, lieber neu bauen als zur Laufzeit installieren, kritische Abhängigkeiten pinnen, automatische Dependabot-Aktualisierungen prüfen und nach jeder sicherheitsrelevanten Änderung erneut verifizieren. Die apko-Lock-Datei pinnt die aufgelösten Wolfi-Pakete; beim Fallback fixiert der gepinnte Basis-Image-Digest dessen Basisidentität, während sich die beim Build verwendeten Ubuntu-Paketquellen weiterhin verändern.

Weitere Grenzen und Hinweise für Vorfälle stehen in [SECURITY.md](SECURITY.md). Vor Änderungen bitte [CONTRIBUTING.md](CONTRIBUTING.md) lesen.

## Lizenz

MIT — siehe [LICENSE](LICENSE).
