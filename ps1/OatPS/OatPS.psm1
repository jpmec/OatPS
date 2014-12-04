

<#
.DESCRIPTION
    Create a Orthogonal Array Testing plan.
#>
function New-OatTestPlan {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        # [parameter(
        #   ValueFromPipeline=$true)]
        # [System.Array]
        # $input,

        [String] $arrayFilePath,
        [String] $inputFilePath
    )

    if ($inputFilePath) {
        $inputObject = GetFileObject($inputFilePath)
    }
    else {
        Write-Warning "No inputFile"
        return
    }

    if (-Not $inputObject) {
        Write-Warning "No inputObject"
        return
    }

    Write-Verbose ($inputObject | ConvertTo-Json)

    # Get the variable names sorted by length
    $test_variable_name_length_pairs = @($inputObject.psobject.properties | % {, @($_.Name, $_.Value.Length)})
    $test_variable_names = @($test_variable_name_length_pairs | Sort-Object {$_[1]}, {$_[0]} | % {$_[0]})

    $input_lengths = GetObjectPropertyLength($inputObject)
    $array_lengths = InitializeOatArrayIndex($arrayFilePath)

    $oat_array = GetBestOatArrayFromLengths $input_lengths $array_lengths

    # Generate string to lookup
    $oat_array_str = ''
    $x = $null
    $y = 0
    foreach ($i in $oat_array) {
        if ($x -eq $null) {
            $x = $i
            $y = 1
        }
        elseif ($x -ne $i) {
            if ($x) {
                $oat_array_str += "$x^$y "
            }

            $x = $i
            $y = 1
        }
        else {
            $y += 1
        }
    }
    if ($x) {
        $oat_array_str += "$x^$y "
        $oat_array_str += "*"
    }

    $oat_array = GetOatArrayFromFile $arrayFilePath

    CreateTestsFromOatArrayAndProperties $oat_array $test_variable_names $inputObject
}


function Get-OatConfig {
    $modulePath = $PSScriptRoot
    return @{
        "ArrayFilePath" = "$modulePath\ts723_Designs.txt"
    }
}




function ConvertFrom-OatJson {
    [CmdletBinding()]

    Param(
        [parameter(ValueFromPipeline=$true)]
        [String] $JsonString
    )

    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
    $jsonserial= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
    $jsonserial.MaxJsonLength  = 67108864
    $Obj = $jsonserial.DeserializeObject($JsonString)

    $Obj
}




function ConvertFrom-OatTxt {
    [CmdletBinding()]

    Param(
        [String] $Path
    )

    $results = @()

    $object = $null

    Get-Content $Path | Where-Object { $_ } | ForEach-Object {

        Write-Verbose "$_"

        $matches = [regex]::matches($_, '^\s+$')

        if ($matches.Success) {
            Write-Verbose "Blank line: '$_'"
            return
        }


        $matches = [regex]::matches($_, '(\d+)\^(\d+)')

        if ($matches.Success) {
            Write-Verbose "Dimension Line: '$_'"
            if ($object)
            {
                #$results += $object
                #put result in pipeline
                $object
            }

            $a = @()
            foreach ($match in $matches)
            {
                $values = $match.Groups | Select-Object Value

                $x = [int] $values[1].Value
                $n = [int] $values[2].Value

                for ($i = 0; $i -lt $n; $i++)
                {
                    $a += ,$x
                }
            }

            $max_value_str_length = $a | Measure-Object -Maximum | % { ([String] $_.Maximum).Length }

            Write-Verbose "Max: $max_value_str_length"

            $object = New-Object PSObject -Property @{
                'Dimensions' = $a
                'MaxDimensionStringLength' = $max_value_str_length
                'Array' = @()
            }

            return
        }

        if ($object) {
            Write-Verbose "Array Line: '$_'"
            Write-Verbose "split length: '$($object.MaxDimensionStringLength)'"
            $split_str = $_ -split "(.{$($object.MaxDimensionStringLength)})" | ? { $_ } | % { [int] $_ }
            Write-Verbose "$($split_str.GetType()) $($split_str.Length)"
            Write-Verbose "$split_str"
            Write-Verbose ($split_str | ConvertTo-Json)
            $object.Array += , $split_str
        }
    }

    if ($object)
    {
#        $results += $object
        $object
    }


#    $results
}




function GetFileObject([String] $filename) {

    Write-Verbose "Reading JSON from $inputFilePath"

    $inputFilePathContent = Get-Content $inputFilePath -Raw

    Write-Verbose "$inputFilePathContent"

    $result = ConvertFrom-Json $inputFilePathContent

    $result
}




function GetObjectPropertyLength($object) {

    $result = @()
    $object.psobject.properties | % {

        $result += $_.Value.Length

    }
    $result = $result | Sort-Object
    $result
}


function GetObjectLengthPropertyMap($object) {
    $object.psobject.properties | ForEach-Object {

    }
}


function ValidateInput([System.Object] $object) {

    $object.psobject.properties | % {
        $_.Value
    }

}




function InitializeOatArrayIndex() {

    $arrays_filename = 'c:\users\Josh\Documents\GitHub\OatPS\ps1\simple_arrays.txt'
    #$arrays_filename = 'c:\users\Josh\Documents\GitHub\OatPS\ps1\ts723_Designs.txt'

    $results = @()
    Get-Content $arrays_filename | % {
        $matches = [regex]::matches($_, '(\d+)\^(\d+)')

        if ($matches.Success) {
            $a = @()
            foreach ($match in $matches)
            {
                $values = $match.Groups | Select-Object Value

                $x = [int] $values[1].Value
                $n = [int] $values[2].Value

                for ($i = 0; $i -lt $n; $i++)
                {
                    $a += ,$x
                }
            }
            $results += , $a
        }
    }

    $results

}




function GetBestOatArrayFromLengths($input_array, $oat_array_lengths) {

    $mustFitLength = $true
    $mustFitSize = $true


    # Get the input array
    $in = @()
    $input_array | %{ $in += $_ }

    Write-Verbose "$input_array"



    if ($mustFitLength)
    {
        $oat_array_lengths = $oat_array_lengths | ? {$in.Length -le $_.Length}
    }


    if ($mustFitSize)
    {
        $oat_array_lengths = $oat_array_lengths | ? {
            for ($i = 0; $i -le $in.Length; $i++)
            {
                if ($_[$i] -lt $in[$i])
                {
                    return $false
                }
            }
            return $true
        }
    }


    $oat_array_lengths | % { Write-Verbose "$_" }

    $subtracted_indexes = @()

    ForEach($index in $oat_array_lengths) {

        $a = $index.Clone()

        $n = [math]::min($a.Length, $in.Length)

        for($i = 0; $i -lt $n; $i++) {

            $x = $a[$i]
            $y = $in[$i]
            $difference = $x- $y
            $a[$i] = $difference
        }

        $subtracted_indexes += , $a
    }


    #$subtracted_indexes | %{ "$_" }


    $min_distance = [double]::PositiveInfinity
    $min_i = -1
    $i = 0
    ForEach($subtracted_index in $subtracted_indexes) {

        $distance = 0

        ForEach($x in $subtracted_index) {
            $distance += ($x * $x)
        }

        if ($distance -lt $min_distance) {
            $min_distance = $distance
            $min_i = $i
        }

        $i += 1
    }

    if ($min_i -ge 0) {
        $oat_array_lengths[$min_i]
    }

}





function InitializeOatArrayIndex($arrays_filename) {

    $results = @()
    Get-Content $arrays_filename | % {
        $matches = [regex]::matches($_, '(\d+)\^(\d+)')

        if ($matches.Success) {
            $a = @()
            foreach ($match in $matches)
            {
                $values = $match.Groups | Select-Object Value

                $x = [int] $values[1].Value
                $n = [int] $values[2].Value

                for ($i = 0; $i -lt $n; $i++)
                {
                    $a += ,$x
                }
            }
            $results += , $a
        }
    }

    $results

}




function GetOatArrayFromFile($filename) {

    $result = @()
    $select = $False
    Get-Content $filename | % {
        if ($select) {
            if ($_ -match '^\s*$') {
                $select = $False
            }
            else {
                $split_str = $_ -split '(.)' | ? {$_} | % {[int] $_}
                $result += , $split_str
            }
        }
        else {
            if ($_ -like $oat_array_str) {
                $select = $True
            }
        }
    }

    return $result
}


function CreateTestsFromOatArrayAndProperties($oat_array, $test_variable_names, $inputObject) {

    Foreach($oat_row in $oat_array) {

        $props = @{}

        for($i = 0; $i -lt $row.Length; $i++) {

            $name = $test_variable_names[$i]
            $index = $oat_row[$i]

            $values = $inputObject.$name
            $value = $values[$index]
            $props[$name] = $value
        }

        if ($props.Length) {
            New-Object PSObject -Property $props
        }
    }
}



export-modulemember *-*
