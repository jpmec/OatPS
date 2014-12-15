

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

        $matches = [regex]::matches($_, '^\s+$')

        if ($matches.Success) {
            return
        }


        $matches = [regex]::matches($_, '(\d+)\^(\d+)')

        if ($matches.Success) {
            if ($object)
            {
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

            $object = New-Object PSObject -Property @{
                'Dimensions' = $a
                'MaxDimensionStringLength' = $max_value_str_length
                'Array' = @()
            }

            return
        }

        if ($object) {
            $split_str = $_ -split "(.{$($object.MaxDimensionStringLength)})" | ? { $_ } | % { [int] $_ }
            $object.Array += , $split_str
        }
    }

    if ($object)
    {
        $object
    }
}




function Get-OatVariableDimension($Variables) {
    $result = @($Variables.psobject.properties | ForEach-Object {$_.Value.Length})
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




export-modulemember *-*
