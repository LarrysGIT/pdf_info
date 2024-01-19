# pdfsize

A recent issue needs to find out system generated pdf page sizes.

PDF pts convert to mm/inchs
`https://stackoverflow.com/questions/34545339/the-size-of-pdf-documents-how-do-i-convert-from-millimeters-to-pixels-using-spi`

```powershell
> # load the class
> . ".\pdfsize.class.ps1"
>
> # load from pdf file
> $pdfinfo = [PdfInfo]::new(".\test.pdf")
> $pdfinfo

PdfFile                                        Pages
-------                                        -----
C:\Users\xxx\Downloads\pdfsize\test.pdf {@{Width=210.016; Height=14.788}, @{Width=210.016; Height=14.788}}
> # page count
> $pdfinfo.Pages.Count
2

> # load from pdf binary
> [byte[]]$pdfbytes = Get-Content .\test.pdf -Encoding Byte
> $pdfinfo = [PdfInfo]::new($pdfbytes)
> $pdfinfo

PdfFile Pages
------- -----
        {@{Width=210.016; Height=14.788}, @{Width=210.016; Height=14.788}}
```
