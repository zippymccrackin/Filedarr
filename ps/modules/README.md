# Bundled importer dependency

powershell-yaml 0.4.12 is bundled so Windows PowerShell launched by Sonarr/Radarr can read config.yml without a user-profile module installation or network access.

The manifest, script module and lib directory are copied unchanged from the installed upstream 0.4.12 package. Upstream project: https://github.com/cloudbase/powershell-yaml

The upstream Apache-2.0 license and copyright notices are retained. The YamlDotNet licenses are retained in each lib target directory. Both net47 (Windows PowerShell) and netstandard2.1 (PowerShell Core) assemblies must be included when distributing Filedarr.
