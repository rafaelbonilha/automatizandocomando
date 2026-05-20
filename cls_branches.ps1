<#
.SYNOPSIS
Verifica as branches antigas e remove conforme solicitacao e registra a atividade em log.

.NOTES
Execute o script em uma sessão PowerShell iniciada com -STA com o comando a seguir:
powershell -STA -File Diretorio\check_swap.ps1 ou .\cls_branches.ps1

.EXAMPLE

Basico.: .\cls_branches.ps1

Autor.: Joao Rafael F. Bonilha - Curso de PowerShell

ATENÇÃO.: Script para estudos de powershell, so use em ambiente de testes/lab e use S e N em maíuscula para encerrar o script.

#>

# Caminho do arquivo de log
$logFile = ".\cleanup-branches.log"

# Funcao para escrever no log
function Write-Log {
    param (
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"

    # Exibe no console
    Write-Host $logMessage

    # Salva no arquivo
    Add-Content -Path $logFile -Value $logMessage
}

Write-Log "Iniciando limpeza de branches locais..."

# Pegar o nome da branch atual
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Log "Branch atual: $currentBranch"

# Listar todas as branches locais
$localBranches = git branch | ForEach-Object { $_.Trim() }

# Branches que deverao ser mantidas
$branchToKeep = @("* $currentBranch", "main", "master", "develop")

Write-Log "Branches protegidas: $($branchToKeep -join ', ')"

# Remover todas as branches exceto as que deverao ser mantidas
$localBranches | Where-Object { $branchToKeep -notcontains $_ } | ForEach-Object {

    $branchName = $_ -replace '^\*\s*', ''

    try {
        git branch -D $branchName | Out-Null
        Write-Log "Branch '$branchName' removida com sucesso!"
    }
    catch {
        Write-Log "Erro ao remover branch '$branchName': $_"
    }
}

Write-Log "Limpeza finalizada."