param (
    [Parameter(Mandatory=$true)]
    [string]$dir, # The directory path that we want to traverse

    [Parameter(Mandatory=$true)]
    [string]$groupName, # The name of the component group that will be generated

    [Parameter(Mandatory=$true)]
    [string]$outputDir # The directory path where the generated file will be saved
)

function GenerateFileParentFolderRelativeTo {
    <#
        .SYNOPSIS
            Given the file full path and another path it computes the file's folder path relative to the other path.

        .PARAMETER fileFullPath
            Represents the file absolute path.

        .PARAMETER otherDirectoryPath
            Represents the path of the directory used to compute the relativeness of the file path.        

        .OUTPUTS
            Returns the file's parent folder path relative to the other directory path.

        .EXAMPLE
            Suppose you have the following directory structure:
            resources
            |---textures
            |   |---texture1.png            

            If you want to compute the relative path of the file "texture1.png" parent folder against the directory "resources"
            you can do the following:

            $fullPath = "C:\resources\textures\texture1.png"
            $otherDirectoryPath = "C:\resources"
            $relativePath = GenerateFileParentFolderRelativeTo -fileFullPath $fullPath -otherDirectoryPath $otherDirectoryPath
            # $relativePath will be "textures"    
    #>

    param (
        [Parameter(Mandatory=$true)]
        [string]$fileFullPath,

        [Parameter(Mandatory=$true)]
        [string]$otherDirectoryPath # The directory path used to compute the relativeness of the file path
    )

    # In order to make the file install in the correct folder, we need to retrieve the 
    # relative path against the input directory        
    $relativePath = $fullPath.Replace($otherDirectoryPath, "")

    # Remove the first slash and the file name, we only want the subfolder
    $relativePath = $relativePath.Substring(1, $relativePath.Length - $_.Name.Length - 1)

    # If the relative path contains a backslash as the last character, remove it
    if ($relativePath.EndsWith("\")) {
        $relativePath = $relativePath.Substring(0, $relativePath.Length - 1)
    }

    return $relativePath
}

function GenerateWXSHeader {
    <#
        .SYNOPSIS
            Generates the WXS file header.

        .OUTPUTS
            Returns the WXS header as a string array.
    #>

    $fileData = @()

    # XML header
    $fileData += "<?xml version=`"1.0`" encoding=`"utf-8`"?>"

    # Just a comment explaining that the file is auto-generated
    $fileData += "<!--" 
    $fileData += "     This file was auto-generated by the CreateWIXComponents.ps1 script with the following parameters:"
    $fileData += "     -dir `"${dir}`" -groupName `"${groupName}`" -outputDir `"${outputDir}`""
    $fileData += "-->"    

    # WIX v4 header
    $fileData += "<Wix xmlns=`"http://wixtoolset.org/schemas/v4/wxs`">"
    # Fragment header
    $fileData += "`t<Fragment>"
    # Component group header
    $fileData += "`t`t<ComponentGroup Id=`"${groupName}Group`" Directory=`"${groupName}`">"

    return $fileData
}

# The path of the directory that we want to travers
# so that we can create the WIX components
$directoryPath = $dir
$absoluteDirectoryPath = (Get-Item -Path $directoryPath | Select-Object -ExpandProperty FullName)

# Generate the WIX header
$fileData = GenerateWXSHeader

# Get all the files in the directory recursively
Get-ChildItem -Path $directoryPath -Recurse -File | ForEach-Object {
    # Create a new variable with the full path of the file
    $fullPath = $_.FullName

    # Generate the file's folder relative path
    $relativePath = GenerateFileParentFolderRelativeTo -fileFullPath $fullPath -otherDirectoryPath $absoluteDirectoryPath

    # Given the relative path, the WiX component wants the attribute "Subdirectory" if it's not empty
    # otherwise we need to set the attribute "Directory" to the name of the component group
    $directoryAttribute = "Directory=`"$groupName`""
    if ($relativePath -ne "") {
        $directoryAttribute = "Subdirectory=`"$relativePath`""
    }

    # Now we need to construct the XML entry for the current file.
    # The XML entry will be a WIX component unde the Component group.
    $fileData += "`t`t`t<Component Id=`"ID_$($_.Name)_COMP`" ${directoryAttribute}>"

    # Add the file entry to the component
    $fileData += "`t`t`t`t<File Id=`"ID_$($_.Name)`" Source=`"$fullPath`" KeyPath=`"yes`" />"    

    # Add the component to the component group
    $fileData += "`t`t`t</Component>"
}

# Component group footer
$fileData += "`t`t</ComponentGroup>"
# Fragment footer
$fileData += "`t</Fragment>"
# WIX footer
$fileData += "</Wix>"

# If the output directory does not exist, create it
if (!(Test-Path -Path $outputDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDir
}

# Write the file data to the file
$fileData | Out-File -FilePath "${outputDir}/${groupName}.wxs" -Encoding utf8
