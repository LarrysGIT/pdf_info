
class PdfInfo {
    $PdfFile
    $Pages = (New-Object System.Collections.ArrayList)

    PdfInfo([string]$PdfPath) {
        $this.PdfFile = Get-Item -Path $PdfPath
        $this.GetPdfPageSizes($this.GetPdfBytes($this.PdfFile.FullName))
    }

    PdfInfo([byte[]]$PdfBytes) {
        $this.GetPdfPageSizes($PdfBytes)
    }

    hidden GetPdfPageSizes([byte[]]$PdfBytes) {
        $PageSizesMatches = [regex]::Matches(([system.text.encoding]::UTF8.GetString($PdfBytes)), "MediaBox *\[[\d\.]+? +?[\d\.]+? +?([\d\.]+?) +?([\d\.]+?)\]")
        for($i = 0; $i -lt $PageSizesMatches.Count; $i++)
        {
            $this.Pages.Add((
                New-Object PSObject -Property ([ordered]@{
                    Width = [math]::Round([decimal]$PageSizesMatches[$i].Groups[1].Value/72*25.4, 3)
                    Height  = [math]::Round([decimal]$PageSizesMatches[$i].Groups[2].Value/72*25.4, 3)
                })
            )) | Out-Null
        }
    }

    hidden [byte[]] GetPdfBytes([string]$PdfPath) {
        return [io.file]::ReadAllBytes($PdfPath)
    }
}
