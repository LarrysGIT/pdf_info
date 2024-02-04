
class PdfInfo {
    $PdfFile
    $PdfVersion
    $IsLastLineEOF
    $PdfInternalObjects = [ordered]@{}
    $Descriptions = (New-Object System.Collections.ArrayList)
    $Fonts = (New-Object System.Collections.ArrayList)
    $Pages = (New-Object System.Collections.ArrayList)

    PdfInfo([string]$PdfPath) {
        $this.PdfFile = Get-Item -Path $PdfPath
        $this.GetPdfObjects($this.GetPdfBytes($this.PdfFile.FullName))
    }

    PdfInfo([byte[]]$PdfBytes) {
        $this.GetPdfObjects($PdfBytes)
    }

    hidden GetPdfObjects([byte[]]$PdfBytes) {
        $PdfAsText = [system.text.encoding]::UTF8.GetString($PdfBytes)
        # objs
        $ObjectMatches = [regex]::Matches($PdfAsText, "(\d+?) \d+? obj[\r\n]+([\s\S]+?)[\r\n]+endobj")
        foreach($obj in $ObjectMatches) {
            $this.PdfInternalObjects[$obj.Groups[1].Value] = $obj.Groups[2].Value
        }
        # trailers
        $this.PdfInternalObjects["Trailers"] = (New-Object System.Collections.ArrayList)
        # some PDFs have multiple trailers
        $TrailerMatches = [regex]::Matches($PdfAsText, "[\r\n]trailer[\r\n ]*(<<[\s\S]+?>>)")
        foreach($trailer in $TrailerMatches) {
            $this.PdfInternalObjects["Trailers"].Add($trailer.Groups[1].Value) | Out-Null
        }
        # Pdf version
        $this.PdfVersion = [regex]::Match($PdfAsText.Substring(0, 20), "^%PDF-(.+?)[\r\n]").Groups[1].Value
        # Pdf file last line should ends with %%EOF
        $this.IsLastLineEOF = $PdfAsText -imatch "[\r\n]%%EOF[\r\n]*$"
    }

    GetPdfDescriptionInfo() {
        class Description {
            $Author
            $Title
            $Subject
            $Keywords
            $Created
            $Modified
            $Application
            $PDFProducer
            $PDFVersion
            $_DescriptionObject
        }
        $i = 0
        foreach($Trailer in $this.PdfInternalObjects["Trailers"]) {
            if($Trailer -imatch "/Info +(\d+)") {
                $Description = [Description]::new()
                $Description._DescriptionObject = $this.PdfInternalObjects[$Matches[1]]
                switch -regex ($this.PdfInternalObjects[$Matches[1]] -ireplace "[\r\n]", " ") {
                    "/Author *\((.*?)\)" {
                        $Description.Author = $Matches[1]
                    }
                    "/Creator *\((.*?)\)" {
                        $Description.Application = $Matches[1]
                    }
                    "/Producer *\((.*?)\)" {
                        $Description.PDFProducer = $Matches[1]
                    }
                    "/CreationDate *\((.*?)\)" {
                        $Description.Created = $Matches[1]
                    }
                    "/ModDate *\((.*?)\)" {
                        $Description.Modified = $Matches[1]
                    }
                    "/Title *\((.*?)\)" {
                        $Description.Title = $Matches[1]
                    }
                }
                $this.Descriptions.Add($Description) | Out-Null
                $i++
            }
        }
    }

    GetPdfPagesInfo() {
        class Page {
            [int]$Id
            $Width = (New-Object PSObject -Property ([ordered]@{mm = 0; pts = 0; inch = 0}))
            $Height = (New-Object PSObject -Property ([ordered]@{mm = 0; pts = 0; inch = 0}))
            $_PageObject
        }
        $i = 0
        foreach($obj in $this.PdfInternalObjects.Keys) {
            $Page = $null
            switch -regex ($this.PdfInternalObjects[$obj] -ireplace "[\r\n]", " "){ 
                "^<<[\s\S]*/Type */Page\b" {
                    $Page = [Page]::new()
                    $Page._PageObject = $this.PdfInternalObjects[$obj]
                    $Page.Id = $i
                    $i++
                    switch -regex ($this.PdfInternalObjects[$obj] -ireplace "[\r\n]", " ") {
                        "/MediaBox *\[ *[-\d\.]+? +?[-\d\.]+? +?([-\d\.]+?) +?([-\d\.]+?) *\]" {
                            $Page.Width.mm = [math]::Round([decimal]$Matches[1]/72*25.4, 3)
                            $Page.Width.pts = [math]::Round([decimal]$Matches[1], 3)
                            $Page.Width.inch = [math]::Round([decimal]$Matches[1]/72, 3)

                            $Page.Height.mm = [math]::Round([decimal]$Matches[2]/72*25.4, 3)
                            $Page.Height.pts = [math]::Round([decimal]$Matches[2], 3)
                            $Page.Height.inch = [math]::Round([decimal]$Matches[2]/72, 3)
                        }
                    }
                }
            }
            if($Page) {
                $this.Pages.Add($Page) | Out-Null
            }
        }
    }

    GetPdfFontsInfo() {
        class Font {
            $Name
            $Encoding
            $Type
            $FontFileObjectId
            $_FontObject
            $_FontDescriptor
        }
        foreach($obj in $this.PdfInternalObjects.Keys) {
            $Font = $null
            switch -regex ($this.PdfInternalObjects[$obj] -ireplace "[\r\n]", " "){ 
                "^<< */BaseFont/(.*?)/" {
                    $FontName = $Matches[1]
                    $FontName = $FontName.Substring($FontName.IndexOf("+") + 1)
                    $Font = $this.Fonts.Where({$_.Name -eq $FontName})[0]
                    if(!$Font) {
                        $Font = [Font]::new()
                    }
                    $Font._FontObject = $this.PdfInternalObjects[$obj]
                    $Font.Name = $FontName
                    switch -regex ($this.PdfInternalObjects[$obj] -ireplace "[\r\n]", " ") {
                        "/Encoding/(.*?)/" {$Font.Encoding = $Matches[1]}
                        "/Subtype/(.*?)/" {$Font.Type = $Matches[1]}
                        "/FontDescriptor +?(\d+)" {
                            $Font._FontDescriptor = $this.PdfInternalObjects[$Matches[1]]
                            switch -regex($this.PdfInternalObjects[$Matches[1]] -ireplace "[\r\n]", " ") {
                                "/FontFile\d* +?(\d+)" {
                                    $Font.FontFileObjectId = $Matches[1]
                                }
                            }
                        }
                    }
                }
                "^<<.*/Type */Font\b" {
                    $FontName = $null
                    if($_ -imatch "/BaseFont */(.+?)(?:>>|/)") {
                        $FontName = $Matches[1]
                    }
                    $FontName = $FontName.Substring($FontName.IndexOf("+") + 1)
                    $Font = $this.Fonts.Where({$_.Name -eq $FontName})[0]
                    if(!$Font) {
                        $Font = [Font]::new()
                    }
                    $Font._FontObject = $this.PdfInternalObjects[$obj]
                    $Font.Name = $FontName
                    switch -regex ($this.PdfInternalObjects[$obj] -ireplace "[\r\n]", " ") {
                        "/Encoding */(.*?)/" {$Font.Encoding = $Matches[1]}
                        "/Subtype */(.*?)/" {$Font.Type = $Matches[1]}
                        "/FontDescriptor +?(\d+)" {
                            $Font._FontDescriptor = $this.PdfInternalObjects[$Matches[1]]
                            switch -regex($this.PdfInternalObjects[$Matches[1]] -ireplace "[\r\n]", " ") {
                                "/FontFile\d* +(\d+)" {
                                    $Font.FontFileObjectId = $Matches[1]
                                }
                            }
                        }
                    }
                }
            }
            if($Font -and $this.Fonts.Name -notcontains $Font.Name) {
                $this.Fonts.Add($Font) | Out-Null
            }
        }
    }

    hidden [byte[]] GetPdfBytes([string]$PdfPath) {
        return [io.file]::ReadAllBytes($PdfPath)
    }
}

<#
$pdfinfo = [pdfinfo]::new("$PWD\test.pdf")
$pdfinfo.GetPdfDescriptionInfo()
$pdfinfo.GetPdfFontsInfo()
$pdfinfo.GetPdfPagesInfo()

$pdfinfo
#>
