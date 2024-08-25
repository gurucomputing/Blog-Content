#Requires -PSEdition Core
$ErrorActionPreference = "Stop"

###
# Global Variables
###

# uid of the outline blog collection
$collectionID = "23ba799f-9926-410c-a5a3-cb7c8923f3b0"

###
# Functions
###

# This function should query the knowledgebase, export the collection supplied
# and download and extract it
# relies on 7zip being installed
function extractOutlineCollection ([String]$collectionID) {  
    [string]$apiEndpointExport = "https://kb.gurucomputing.com.au/api/collections.export"
    [string]$apiEndpointInfo = "https://kb.gurucomputing.com.au/api/fileOperations.info"
    [string]$apiEndpointGet = "https://kb.gurucomputing.com.au/api/fileOperations.redirect"
    [string]$apiEndpointDelete = "https://kb.gurucomputing.com.au/api/fileOperations.delete"

    Write-Host "exporting blog collection"
    # Define request headers
    $headers = @{
        Authorization = "Bearer $env:OUTLINE_API_KEY"
        ContentType   = "application/json"
    }
    $body = @{
        format = 'outline-markdown'
        id     = "$collectionID"
    }

    # Make the POST request
    $fileOperation = (Invoke-RestMethod -Uri $apiEndpointExport -Method Post -Headers $headers -Body $body).data.fileOperation

    Write-Host "waiting for export to complete"
    # poll until the file operation is complete
    while ($true) {
        sleep 1
        $body = @{id = "$($fileOperation.id)" }
        $currentStatus = (Invoke-RestMethod -Uri $apiEndpointInfo -Method Post -Headers $headers -Body $body).data
        if ($currentStatus.state -eq "complete") {
            write-host "downloading the export"
            # get the file
            Invoke-WebRequest -Header $headers -Method Post -Body $body $ApiEndpointGet -OutFile blog.zip
            # delete the export
            write-host "deleting the export"
            Invoke-RestMethod -Uri $apiEndpointDelete -Method Post -Headers $headers -Body $body
            break
        }
    }
    write-host "Extracting `'blog.zip`' to `'$pwd/../build/docs`' and deleting `'blog.zip`'"
    unzip "blog.zip"
    mkdir "../build"
    mv Blog "../build/docs"
    rm -f "blog.zip"
    write-host "done"
}

# This function takes a location of a markdown file
# and transforms it from outline format to material for mkdocs
# format
function transformMarkdown($markdownLoc) {
    $fileContent = get-content $markdownLoc -raw
    #remove title
    $fileContent = $fileContent -replace "^#(.*?)\n\n",""

    #change info notices to mkdocs syntax
    $pattern = ":::info((.|\n)*?):::"
    # Perform the regex match and replacement
    $matching = [regex]::Matches($fileContent, $pattern)
    # Iterate through each match and replace
    foreach ($match in $matching) {
        $replace = $match.Groups[1].Value -replace "`n`n","`n"
        $replace = $replace.replace("`n","`n    ")
        $fileContent = $fileContent.replace($match.Value, "!!! info$replace")
    }

    # change warning notices to mkdocs syntax
    $pattern = ":::warning((.|\n)*?):::"
    # Perform the regex match and replacement
    $matching = [regex]::Matches($fileContent, $pattern)
    # Iterate through each match and replace
    foreach ($match in $matching) {
        $replace = $match.Groups[1].Value -replace "`n`n","`n"
        $replace = $replace.replace("`n","`n    ")
        $fileContent = $fileContent.replace($match.Value, "!!! warning$replace")
    }

    # centre align all images (if not already ran)
    if (!$fileContent.contains('<figure markdown="1">')) {
        #centre aline all images and add captions
        $pattern = ' !\[(.*?)\]\(.*?\)'
        # Perform the regex match and replacement
        $matching = [regex]::Matches($fileContent, $pattern)
        foreach ($match in $matching) {
            $filecontent = $filecontent.replace($match.Value, "<figure markdown=`"1`">`n$($match.groups[0].Value)`n<figcaption>$($match.groups[1].Value)</figcaption>`n</figure>")
        }
    }
    
    # remove any blank lines
    $fileContent = $fileContent.replace("\`n", "")
    
    return $fileContent
}

###
# Script
###
# clean the build directory
rm -rf "/data/blog/build"

# move to the script folder
Push-Location $PSScriptRoot

# download and extract the Blog
extractOutlineCollection($collectionID)

# Convert to Material for Mkdocs Markdown Format for every markdown file in the blog folder
Write-Host "Transforming Markdown"
get-childitem -Recurse ../build/docs | Where-Object {$_.extension -eq ".md"} | ForEach-Object {
    set-content -path $_.fullName -value (transformMarkdown($_.FullName))
}

write-host "Copying Static Files"
&cp -rf ../site-static/* ../build

write-host "building site"
pip install mkdocs-material

&mkdocs build -f ../build/mkdocs.yml

Pop-Location