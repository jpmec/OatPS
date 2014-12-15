

<#
.DESCRIPTION
    Create a Orthogonal Array Testing plan.
#>
function New-OatTestPlan {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory=$true)]
        $Variables,
        $OatArrays
    )

    $array_difference_threshold = 4

    if (-Not $Variables) {
        Write-Warning "Must provide $Variables"
        return
    }

    if ($Variables -is [String]) {

        if ((Test-Path -IsValid $Variables) -And (Test-Path $Variables)) {

            $Variables = Get-ChildItem $Variables |
                Where-Object { $_.Extension -match '.json' } |
                Get-Content -Raw |
                ConvertFrom-Json
        }
        else {
            $Variables = $Variables | ConvertFrom-Json
        }
    }

    if ($Variables -isnot [PSCustomObject]) {
        Write-Warning "Cannot use Variables of type $($Variables.GetType())"
        return
    }

    #Write-Verbose $Variables


    if (-Not $OatArrays) {
        $OatArrays = Get-Content "$PSScriptRoot\OatArrays.json" -Raw | ConvertFrom-OatJson
    }

    if ($OatArrays -is [String]) {
        if (Test-Path -IsValid $OatArrays -And Test-Path $OatArrays) {

            $OatArrays = Get-ChildItem $OatArrays |
                Where-Object { $_.Extension -match '.json' } |
                Get-Content -Raw |
                ConvertFrom-Json
        }
    }

    if ($OatArrays -isnot [System.Object[]]) {
        Write-Warning "Cannot use OatArrays of type $($OatArrays.GetType())"
        return
    }


    $variable_dimensions = Get-OatVariableDimension $Variables
    $variable_names = @($Variables | ForEach-Object {$_.psobject.properties.Name})

    $OatArrays |
    ForEach-Object {

        $length_difference = $_.Dimensions.Length - $variable_dimensions.Length

        $array_difference = Get-ArrayDifference $_.Dimensions $variable_dimensions

        $array_difference_negative_count = $array_difference | ForEach-Object {$count = 0} {If ($_ -lt 0) {$count += 1}} {return $count}

        $array_difference_sum_of_squares = Get-ArrayDotProduct $array_difference $array_difference

        $metrics = [PSCustomObject] @{
            "DimensionsLengthDifference" = $length_difference
            "DimensionsArrayDifference" = $array_difference
            "DimensionsArrayDifferenceSS" = $array_difference_sum_of_squares
            "DimensionsArrayDifferenceNegativeCount" = $array_difference_negative_count
            "OatArray" = $_
        }

        $metrics
    } |
    Where-Object DimensionsLengthDifference -ge 0 |
    Where-Object DimensionsArrayDifferenceNegativeCount -eq 0 |
    Where-Object {
        $_.DimensionsArrayDifferenceSS -le $array_difference_threshold
    } |
    Sort-Object DimensionsArrayDifferenceSS |
    ForEach-Object {

        Foreach($oat_row in $_.OatArray.Array) {

            $props = @{}

            $n = [math]::min($oat_row.Length, $variable_names.Length)
            for($i = 0; $i -lt $n; $i++) {

                $name = $variable_names[$i]
                $index = $oat_row[$i]

                $values = $Variables.$name
                $value = $values[$index]
                $props[$name] = $value
            }

            if ($props.Length) {
                New-Object PSObject -Property $props
            }
        }



    }


    # if ($inputFilePath) {
    #     $inputObject = GetFileObject($inputFilePath)
    # }
    # else {
    #     Write-Warning "No inputFile"
    #     return
    # }

    # if (-Not $inputObject) {
    #     Write-Warning "No inputObject"
    #     return
    # }

    # Write-Verbose ($inputObject | ConvertTo-Json)

    # # Get the variable names sorted by length
    # $test_variable_name_length_pairs = @($inputObject.psobject.properties | % {, @($_.Name, $_.Value.Length)})
    # $test_variable_names = @($test_variable_name_length_pairs | Sort-Object {$_[1]}, {$_[0]} | % {$_[0]})

    # $input_lengths = GetObjectPropertyLength($inputObject)
    # $array_lengths = InitializeOatArrayIndex($arrayFilePath)

    # $oat_array = GetBestOatArrayFromLengths $input_lengths $array_lengths

    # # Generate string to lookup
    # $oat_array_str = ''
    # $x = $null
    # $y = 0
    # foreach ($i in $oat_array) {
    #     if ($x -eq $null) {
    #         $x = $i
    #         $y = 1
    #     }
    #     elseif ($x -ne $i) {
    #         if ($x) {
    #             $oat_array_str += "$x^$y "
    #         }

    #         $x = $i
    #         $y = 1
    #     }
    #     else {
    #         $y += 1
    #     }
    # }
    # if ($x) {
    #     $oat_array_str += "$x^$y "
    #     $oat_array_str += "*"
    # }

    # $oat_array = GetOatArrayFromFile $arrayFilePath

    # CreateTestsFromOatArrayAndProperties $oat_array $test_variable_names $inputObject
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

    # $Obj | ForEach-Object {
    #     $ht = @{}
    #     $ht += $Obj
    #     [PSCustomObject]$ht
    # }

    $Obj | ForEach-Object {
        $props = @{}
        $_.GetEnumerator() | ForEach-Object {
            $props[$_.Key] = $_.Value
        }

        [PSCustomObject]$props
    }
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




function Get-OatVariableDimension($Variables) {
    $result = @()
    $Variables.psobject.properties | % {

        $result += $_.Value.Length

    }
    $result = $result | Sort-Object
    $result
}




function Get-ArrayDifference {
    [CmdletBinding()]
    Param(
        $a,
        $b
    )

    if ($a.Length -ge $b.Length) {
        $result = $a.Clone()
    }
    else {
        $result = $b.Clone()
    }

    $n = [math]::min($a.Length, $b.Length)

    for($i = 0; $i -lt $n; $i++) {

        $x = $a[$i]
        $y = $b[$i]
        $difference = $x- $y
        $result[$i] = $difference
    }

    $result
}


function Get-ArrayDotProduct{
    [CmdletBinding()]
    Param(
        $a,
        $b
    )

    $result = 0

    $n = [math]::min($a.Length, $b.Length)

    for ($i = 0; $i -lt $n; $i++) {
        $result += $a[$i] * $b[$i]
    }

    return $result
}





function Get-OatArray($Variables, $OatArrays) {


    if ($OatArrays -eq $null) {
        $OatArrays = Get-Content "$PSScriptRoot\OatArrays.json" -Raw | ConvertFrom-OatJson
    }

    if ($Variables -eq $null) {
        return $OatArrays
    }

    $variables_dimensions = Get-OatVariableDimension $Variables

    # create filters
    $dimensionLengthEqualsFilter = { $_.Dimensions.Length -eq $variables_dimensions.Length }
    $dimensionValueEqualsFilter = {
            $n = $variables_dimensions.Length
            for ($i = 0; $i -le $n; $i++)
            {
                if ($_.Dimensions[$i] -ne $variables_dimensions[$i])
                {
                    return $false
                }
            }
            return $true
    }


    $dimensionDistanceFilter = {
        $n = $variables_dimensions.Length


    }

    $OatArrays = $OatArrays | Where-Object -filterScript $dimensionLengthEqualsFilter
    $OatArrays = $OatArrays | Where-Object -filterScript $dimensionValueEqualsFilter

    $OatArrays


    # $oat_array_lengths | % { Write-Verbose "$_" }

    # $subtracted_indexes = @()

    # ForEach($index in $oat_array_lengths) {

    #     $a = $index.Clone()

    #     $n = [math]::min($a.Length, $in.Length)

    #     for($i = 0; $i -lt $n; $i++) {

    #         $x = $a[$i]
    #         $y = $in[$i]
    #         $difference = $x- $y
    #         $a[$i] = $difference
    #     }

    #     $subtracted_indexes += , $a
    # }


    # #$subtracted_indexes | %{ "$_" }


    # $min_distance = [double]::PositiveInfinity
    # $min_i = -1
    # $i = 0
    # ForEach($subtracted_index in $subtracted_indexes) {

    #     $distance = 0

    #     ForEach($x in $subtracted_index) {
    #         $distance += ($x * $x)
    #     }

    #     if ($distance -lt $min_distance) {
    #         $min_distance = $distance
    #         $min_i = $i
    #     }

    #     $i += 1
    # }

    # if ($min_i -ge 0) {
    #     $oat_array_lengths[$min_i]
    # }

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
