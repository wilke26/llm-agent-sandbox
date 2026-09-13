# Contributing

Security-preserving changes are welcome. Keep this template small and portable across Linux, macOS and Windows with Linux containers.

Before submitting a change:

1. Explain any new package, mount, network path, capability or writable location.
2. Update `docs/THREAT-MODEL.md` for changes to trust boundaries or residual risk.
3. Keep Bash compatible with common macOS/Linux shells and PowerShell compatible with PowerShell 7 and Windows PowerShell 5.1 where practical.
4. Run `docker compose config`, build the image, start the service, and run the appropriate verification script.
5. Do not commit `.env`, workspace contents, credentials, generated images or container logs.

Security controls should fail closed. A platform-specific exception belongs in an explicit local override plus documentation, not in the portable defaults.
