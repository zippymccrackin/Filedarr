param (
    [string]$TestPath = (Resolve-Path "./tests/ps").Path,
    [string]$SourcePath = (Resolve-Path "./ps").Path,
    [string]$OutputPath = "./coverage"
)

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory | Out-Null
}

$codeCoverageFiles = Get-ChildItem -Path $SourcePath -Recurse -Filter *.ps1 | Select-Object -ExpandProperty FullName

$configuration = @{
    Run = @{
        Path = $TestPath
        Exit = $false
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Detailed'
        Capture = 'All'
    }
    CodeCoverage = @{
        Enabled = $true
        Path = $codeCoverageFiles
        OutputFormat = 'Cobertura'
        OutputPath = (Join-Path $OutputPath 'coverage.xml')
    }
    Debug = @{
        WriteDebugMessages = $False
    }
}


# Capture Pester output to a file
$pesterOutputPath = Join-Path $OutputPath 'pester-output.txt'

$results = & {
    Invoke-Pester -Configuration $configuration
} *>&1 | Tee-Object -FilePath $pesterOutputPath
$results | Format-List * -Force | Out-File "$OutputPath\pester-results.txt"

# Check if coverage.xml was generated
$coverageXml = Join-Path $OutputPath 'coverage.xml'
if (-not (Test-Path $coverageXml)) {
    Write-Warning "No code coverage data file found at $coverageXml. Are your tests running code in '$SourcePath'?"
    return
}

# For now, just notify the user:
Write-Host "Coverage XML generated at $coverageXml."

# Parse missed commands from Pester output
$missedCommands = @()
if (Test-Path $pesterOutputPath) {
    $lines = Get-Content $pesterOutputPath -Raw -Encoding UTF8
    if ($lines -match '(?ms)Missed command:(.+?)(?:\n\n|$)') {
        $missedBlock = $matches[1]
        $missedLines = $missedBlock -split "`n" | Where-Object { $_ -match '\S' -and -not ($_ -match 'File +Class +Function +Line +Command') }
        foreach ($line in $missedLines) {
            $parts = $line -split '\s{2,}', 5
            if ($parts.Count -ge 5) {
                $missedCommands += [PSCustomObject]@{
                    File = $parts[0]
                    Class = $parts[1]
                    Function = $parts[2]
                    Line = $parts[3]
                    Command = $parts[4]
                }
            }
        }
    }
}
$coverageData = @()
[xml]$xml = Get-Content $coverageXml


# Parse Pester test results for total test counts

# Global test counters for summary
$totalPassed = 0; $totalFailed = 0; $totalTests = 0
if ($results -and $results.Tests) {
    foreach ($test in $results.Tests) {
        $totalTests++
        if ($test.Result -eq 'Passed') { $totalPassed++ }
        elseif ($test.Result -eq 'Failed') { $totalFailed++ }
    }
}

$coverageDataFiles = @()
# Parse coverage XML
foreach ($class in $xml.coverage.packages.package.classes.class) {
    $file = $class.filename
    $lines = $class.lines.line
    $covered = ($lines | Where-Object { $_.hits -gt 0 }).Count
    $total = $lines.Count
    if ($total -eq $null -or $total -eq 0) {
        $covered = 0
        $total = 0
        $percent = 100
    } else {
        $percent = [math]::Round(($covered / $total) * 100, 2)
    }
    # Per-file test counters
    $success = 0; $fail = 0; $fileTotalTests = 0
    if ($results -and $results.Tests) {
        $sourceBase = [System.IO.Path]::GetFileNameWithoutExtension($file)
        foreach ($test in $results.Tests) {
            if ($test.ScriptBlock.File) {
                $testFile = [System.IO.Path]::GetFileName($test.ScriptBlock.File)
                $testBase = $testFile -replace '\.tests\.', '.'
                $testBase = [System.IO.Path]::GetFileNameWithoutExtension($testBase)
                if ($testBase -eq $sourceBase) {
                    $fileTotalTests++
                    if ($test.Result -eq 'Passed') { $success++ }
                    elseif ($test.Result -eq 'Failed') { $fail++ }
                }
            }
        }
    }
    $coverageDataFiles += [PSCustomObject]@{
        File = $file
        LinesCovered = $covered
        TotalLines = $total
        PercentCovered = $percent
        SuccessfulTests = $success
        FailedTests = $fail
        TotalTests = $fileTotalTests
    }
}

$coverageData = @{
    Summary = @{
        GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SourcePath = (Resolve-Path $SourcePath).Path
        TestPath = (Resolve-Path $TestPath).Path
        TotalTests = $totalTests
        SuccessfulTests = $totalPassed
        FailedTests = $totalFailed
        PercentSuccessful = if ($totalTests -gt 0) { [math]::Round(($totalPassed / $totalTests) * 100, 2) } else { 100 }
        PercentCoverage = if ($coverageDataFiles.Count -gt 0) { [math]::Round((($coverageDataFiles | Measure-Object -Property LinesCovered -Sum).Sum / ($coverageDataFiles | Measure-Object -Property TotalLines -Sum).Sum) * 100, 2) } else { 100 }
    }
    Files = $coverageDataFiles
}

# Export to CSV
$csvPath = Join-Path $OutputPath "coverage-summary.csv"
$coverageData | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "CSV saved to $csvPath"

# Export to JSON
$jsonPath = Join-Path $OutputPath "coverage-summary.json"
$coverageData | ConvertTo-Json -Depth 5 | Out-File $jsonPath
Write-Host "JSON saved to $jsonPath"


# Modern HTML/CSS/JS coverage report
$htmlPath = Join-Path $OutputPath "coverage-report.html"
$csvFile = "coverage-summary.csv"
$jsonFile = "coverage-summary.json"

$modernCss = @'
<style>
body {
    font-family: "Segoe UI", Arial, sans-serif;
    background: #f7f8fa;
    color: #222;
    margin: 0;
    padding: 0;
}
.container {
    max-width: 1100px;
    margin: 2em auto;
    background: #fff;
    border-radius: 10px;
    box-shadow: 0 2px 8px #0001;
    padding: 2em 2em 1em 2em;
}
h1, h2 {
    margin-top: 0;
}
.summary {
    display: flex;
    gap: 2em;
    margin-bottom: 1.5em;
    flex-wrap: wrap;
    justify-content: space-around;
}
.summary-item {
    background: #f0f4f8;
    border-radius: 6px;
    padding: 1em 2em;
    font-size: 1.1em;
    box-shadow: 0 1px 3px #0001;
    text-align: center;
}
.export-btns {
    margin-bottom: 1.5em;
}
.export-btns button {
    background: #0078d4;
    color: #fff;
    border: none;
    border-radius: 4px;
    padding: 0.5em 1.2em;
    margin-right: 1em;
    font-size: 1em;
    cursor: pointer;
    transition: background 0.2s;
}
.export-btns button:hover {
    background: #005fa3;
}
table.coverage {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 2em;
    background: #fff;
}
table.coverage th, table.coverage td {
    padding: 0.6em 0.5em;
    text-align: center;
}
table.coverage th {
    background: #e3eaf2;
    position: sticky;
    top: 0;
    z-index: 2;
}
table.coverage tr {
    transition: background 0.2s;
}
table.coverage tr:hover {
    background: #f0f8ff;
}
tr.covered { background: #e8fbe8; }
tr.uncovered { background: #ffeaea; }
tr.partial { background: #fffbe5; }
tr.failed { background: #ffcccc; }
.collapsible {
    margin-bottom: 1.5em;
}
details > summary {
    font-size: 1.1em;
    font-weight: bold;
    cursor: pointer;
    outline: none;
    margin-bottom: 0.5em;
}
.failed-test {
    margin-bottom: 1em;
    padding: 0.5em;
    border: 1px solid #f00;
    background: #fee;
    border-radius: 6px;
}
.uncovered-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 0.5em;
}
.uncovered-table th, .uncovered-table td {
    padding: 0.3em 0.5em;
    border-bottom: 1px solid #eee;
    text-align: left;
    font-family: "Fira Mono", "Consolas", monospace;
}
.uncovered-table th {
    background: #f7f7f7;
}
</style>
'@

$exportJs = @'
<script>
function downloadFile(file, type) {
    fetch(file)
        .then(resp => resp.blob())
        .then(blob => {
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.style.display = 'none';
            a.href = url;
            a.download = file;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
        });
}
</script>
'@

$htmlContent = @()
$htmlContent += '<div class="container">'
$htmlContent += '<h1>FileDarr PowerShell Testing Report</h1>'
$htmlContent += "<div class='summary'>"
$htmlContent += "<div class='summary-item'><b>Total Tests:</b><br>$totalTests</div>"
$htmlContent += "<div class='summary-item'><b>Successful:</b><br>$totalPassed</div>"
$htmlContent += "<div class='summary-item'><b>Failed:</b><br>$totalFailed</div>"
$htmlContent += "</div>"
$htmlContent += '<div class="export-btns">'
$htmlContent += '<button onclick="downloadFile(''coverage-summary.csv'')">Export CSV</button>'
$htmlContent += '<button onclick="downloadFile(''coverage-summary.json'')">Export JSON</button>'
$htmlContent += '</div>'

# Table
$tableHeader = "<tr><th>File</th><th>Lines<br />Covered</th><th>Total<br />Lines</th><th>Percent<br />Covered</th><th>Successful<br />Tests</th><th>Failed<br />Tests</th><th>Total<br />Tests</th></tr>"
$tableRows = $coverageData.Files | ForEach-Object {
        $rowClass = if ($_.PercentCovered -eq 100) { 'covered' } elseif ($_.PercentCovered -eq 0) { 'uncovered' } elseif ($_.PercentCovered -lt 100) { 'partial' } else { '' }
        if ($_.FailedTests -gt 0) { $rowClass += ' failed' }
        $row = "<tr class='$rowClass'>"
        $row += "<td style='text-align: left;'>$($_.File)</td>"
        $row += "<td>$($_.LinesCovered)</td>"
        $row += "<td>$($_.TotalLines)</td>"
        $row += "<td>$($_.PercentCovered)</td>"
        $row += "<td>$($_.SuccessfulTests)</td>"
        $row += "<td>$($_.FailedTests)</td>"
        $row += "<td>$($_.TotalTests)</td>"
        $row += "</tr>"
        $row
}
$htmlContent += "<table class='coverage'>" + $tableHeader + ($tableRows -join "`n") + "</table>"

# Failed tests collapsible
$failedTestsHtml = ''
if ($results -and $results.Tests) {
        $failed = $results.Tests | Where-Object { $_.Result -eq 'Failed' }
        if ($failed.Count -gt 0) {
                $failedTestsHtml += "<details class='collapsible'><summary style='color:#b00;'>Failed Tests ($($failed.Count))</summary>"
                foreach ($test in $failed) {
                        $failedTestsHtml += "<div class='failed-test'>"
                        $failedTestsHtml += "<b>Test:</b> $($test.Name)<br>"
                        $failedTestsHtml += "<b>File:</b> $($test.ScriptBlock.File)<br>"
                        $failedTestsHtml += "<b>Line:</b> $($test.ScriptBlock.StartPosition.StartLine)<br>"
                        $failedTestsHtml += "<b>Message:</b> $($test.ErrorRecord.Exception.Message)<br>"
                        if ($test.ErrorRecord.ScriptStackTrace) {
                                $failedTestsHtml += "<b>StackTrace:</b> <pre style='white-space:pre-wrap;'>$($test.ErrorRecord.ScriptStackTrace)</pre>"
                        }
                        $failedTestsHtml += '</div>'
                }
                $failedTestsHtml += '</details>'
        }
}
$htmlContent += $failedTestsHtml

# Uncovered lines collapsible per file
foreach ($class in $xml.coverage.packages.package.classes.class) {
        $file = $class.filename
        $lines = $class.lines.line
        $uncovered = $lines | Where-Object { $_.hits -eq 0 }
        if ($uncovered) {
                $htmlContent += "<details class='collapsible'><summary>Uncovered lines in $file</summary>"
                $filePath = Join-Path $SourcePath ($file -replace '/', '\')
                $fileLines = @()
                if (Test-Path $filePath) {
                        $fileText = Get-Content -Path $filePath -Raw -Encoding UTF8
                        $fileLines = $fileText -split "`n"
                }
                $lineObjects = $uncovered | ForEach-Object {
                        $lineNum = [int]$_.number
                        $code = if ($fileLines.Count -ge $lineNum) { $fileLines[$lineNum - 1] } else { '' }
                        [PSCustomObject]@{ Line = $lineNum; Code = $code }
                }
                $htmlContent += "<table class='uncovered-table'><tr><th>Line</th><th>Code</th></tr>"
                foreach ($obj in $lineObjects) {
                        $htmlContent += "<tr><td>$($obj.Line)</td><td><pre style='margin:0;'>$([System.Web.HttpUtility]::HtmlEncode($obj.Code))</pre></td></tr>"
                }
                $htmlContent += "</table>"
                $htmlContent += '</details>'
        }
}

# Missed commands (command coverage) section
if ($missedCommands.Count -gt 0) {
    $htmlContent += "<details class='collapsible'><summary style='color:#b00;'>Missed Commands ($($missedCommands.Count))</summary>"
    $htmlContent += "<table class='uncovered-table'><tr><th>File</th><th>Line</th><th>Command</th></tr>"
    foreach ($cmd in $missedCommands) {
        $file = $cmd.File
        $line = $cmd.Line
        $command = [System.Web.HttpUtility]::HtmlEncode($cmd.Command)
        $htmlContent += "<tr><td>$file</td><td>$line</td><td><pre style='margin:0;'>$command</pre></td></tr>"
    }
    $htmlContent += "</table></details>"
}

$htmlContent += '</div>'

$flatHtml = @('<html><head><title>FileDarr PowerShell Testing Report</title>' + $modernCss + $exportJs + '</head><body>')
$flatHtml += $htmlContent | ForEach-Object { $_.ToString() }
$flatHtml += '</body></html>'
$flatHtml -join "`n" | Out-File $htmlPath -Encoding UTF8
Write-Host "HTML saved to $htmlPath"