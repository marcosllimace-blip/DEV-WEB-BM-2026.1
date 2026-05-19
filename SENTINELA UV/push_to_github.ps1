<#
push_to_github.ps1

Uso:
  - Executar sem parâmetros: assume usuário 'marcosllimace-blip' e repositório 'SENTINELA-UV', não tenta criar remoto com gh
  - Exemplo (usar remote já criado no GitHub):
      .\push_to_github.ps1 -Path "C:\Users\marco\OneDrive\Desktop\SENTINELA UV"

  - Exemplo (tentar criar o repo automaticamente usando gh):
      .\push_to_github.ps1 -CreateRemote -Path "." -GitHubUser "marcosllimace-blip" -RepoName "SENTINELA-UV"

Parâmetros:
  -Path        : caminho para a pasta do projeto (padrão: '.')
  -GitHubUser  : seu usuário GitHub (padrão: marcosllimace-blip)
  -RepoName    : nome do repositório no GitHub (padrão: SENTINELA-UV)
  -CreateRemote: tenta criar o repositório usando 'gh' (se disponível)
  -Private     : se usado junto com -CreateRemote, cria o repo privado; caso contrário cria público
#>

param(
    [string]$Path = ".",
    [string]$GitHubUser = "marcosllimace-blip",
    [string]$RepoName = "SENTINELA-UV",
    [switch]$CreateRemote,
    [switch]$Private
)

function Exec-Git {
    param([string]$Args)
    $cmd = "git $Args"
    Write-Host "> $cmd"
    $proc = Start-Process -FilePath git -ArgumentList $Args -NoNewWindow -Wait -PassThru -RedirectStandardOutput -RedirectStandardError
    return $proc.ExitCode
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git não encontrado. Instale o Git e tente novamente: https://git-scm.com/downloads"
    exit 1
}

Set-Location -Path $Path
Write-Host "Diretório atual: $(Get-Location)"

if (-not (Test-Path -Path ".git")) {
    Write-Host "Não há repositório Git. Inicializando... (branch 'main')"
    git init -b main
} else {
    Write-Host "Repositório Git já inicializado."
}

if ($CreateRemote) {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $vis = if ($Private) {"--private"} else {"--public"}
        Write-Host "Tentando criar repositório remoto com gh: $GitHubUser/$RepoName ($vis)"
        # -y não existe em todas as versões; usar --confirm quando necessário
        $ghArgs = @("repo", "create", "$GitHubUser/$RepoName", $vis, "--source=.", "--remote=origin", "--push")
        Write-Host "> gh $($ghArgs -join ' ')"
        $proc = Start-Process -FilePath gh -ArgumentList $ghArgs -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            Write-Warning "Comando 'gh repo create' retornou código $($proc.ExitCode). Verifique autenticação ou crie o repositório manualmente."
        }
        exit $proc.ExitCode
    } else {
        Write-Warning "Flag -CreateRemote usada, mas 'gh' não foi encontrado neste sistema. Instale o GitHub CLI ou crie o repo manualmente no GitHub."
    }
}

# Configurar remote origin (adicionar ou atualizar)
$remoteUrl = "https://github.com/$GitHubUser/$RepoName.git"
$existingRemotes = git remote
if ($LASTEXITCODE -ne 0) { Write-Warning "Não foi possível listar remotes (exit $LASTEXITCODE). Continuando..." }

if ($existingRemotes -match "origin") {
    Write-Host "Remote 'origin' já existe. Atualizando URL para: $remoteUrl"
    git remote set-url origin $remoteUrl
} else {
    Write-Host "Adicionando remote 'origin' -> $remoteUrl"
    git remote add origin $remoteUrl
}

Write-Host "Garantindo que o branch principal se chame 'main'"
git branch -M main

Write-Host "Enviando para o remoto..."
git push -u origin main
$exit = $LASTEXITCODE
if ($exit -ne 0) {
    Write-Error "git push falhou com código $exit. Possíveis causas: repositório remoto não existe, problemas de autenticação (use um PAT), ou conflito de histórico."
    Write-Host "Se pedir usuário/senha, use seu usuário GitHub e um Personal Access Token como senha. Para criar um PAT: https://github.com/settings/tokens"
    exit $exit
}

Write-Host "Push realizado com sucesso. Verifique: https://github.com/$GitHubUser/$RepoName"
