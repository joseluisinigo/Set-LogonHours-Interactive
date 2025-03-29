<#
.SYNOPSIS
    Interactive script to assign logon hour restrictions to AD users.

.DESCRIPTION
    This script allows administrators to configure Active Directory logon hour restrictions
    for users in a specific OU. It supports multiple time ranges and days of week.

.NOTES
    - Active Directory stores logon hours as a 21-byte array where Sunday is day 0
    - Only whole hours are supported (minutes are ignored)
    - Time ranges are inclusive of start hour and exclusive of end hour

.AUTHOR
    Jose Luis Iñigo a.k.a. Riskoo
    https://joseluisinigo.work
    info@joseluisinigo.work
    https://github.com/joseluisinigo

.LICENSE
    MIT License
#>

Import-Module ActiveDirectory

# Display reference for day abbreviations to help user input
function Show-DayLegend {
    Write-Host "`nDay reference for input:"
    Write-Host "  Sunday       → Su"
    Write-Host "  Monday       → M"
    Write-Host "  Tuesday      → T"
    Write-Host "  Wednesday    → W"
    Write-Host "  Thursday     → Th"
    Write-Host "  Friday       → F"
    Write-Host "  Saturday     → Sa`n"
}

# Returns a mapping of day names/abbreviations to their numerical index (Sunday = 0)
function Get-DayMap {
    return @{
        "Su" = 0; "Sunday" = 0;    # Sunday is day 0 in AD
        "M"  = 1; "Monday" = 1;
        "T"  = 2; "Tuesday" = 2;
        "W"  = 3; "Wednesday" = 3;
        "Th" = 4; "Thursday" = 4;
        "F"  = 5; "Friday" = 5;
        "Sa" = 6; "Saturday" = 6
    }
}

# Converts time string input to an hour integer (0-23)
# Note: Active Directory only supports whole hours (minutes are ignored)
function ConvertToHour($inputTime) {
    try {
        $timeString = $inputTime.Trim()
        
        # Handle AM/PM format
        if ($timeString -match '(\d+)(?::(\d+))?\s*(AM|PM)$') {
            $hour = [int]$matches[1]
            if ($matches[3] -eq 'PM' -and $hour -ne 12) {
                $hour += 12
            }
            if ($matches[3] -eq 'AM' -and $hour -eq 12) {
                $hour = 0
            }
            # Warn if minutes were specified (AD ignores them)
            if ($matches[2] -and $matches[2] -ne "00") {
                Write-Host "⚠️ Note: Active Directory only supports whole hour blocks. Using $hour:00" -ForegroundColor Yellow
            }
            return $hour
        }
        # Handle 24-hour format with or without minutes
        elseif ($timeString -match '^(\d+)(?::(\d+))?$') {
            $hour = [int]$matches[1]
            # Warn if minutes were specified (AD ignores them)
            if ($matches[2] -and $matches[2] -ne "00") {
                Write-Host "⚠️ Note: Active Directory only supports whole hour blocks. Using $hour:00" -ForegroundColor Yellow
            }
            return $hour
        }
        else {
            throw "❌ Invalid time format: '$inputTime'"
        }
    } catch {
        throw "❌ Cannot parse time: '$inputTime'. Use formats like '16:00' or '4PM'"
    }
}

# Apply the configured logon hours to selected AD users
function Apply-LogonHours($users, $tramos) {
    $dayMap = Get-DayMap
    $logonHours = New-Object byte[] 21
    
    # Initialize with 0 (all access denied)
    for ($i = 0; $i -lt 21; $i++) {
        $logonHours[$i] = 0
    }

    foreach ($tramo in $tramos) {
        $daysRange = $tramo.Days
        $startHour = $tramo.Start
        $endHour = $tramo.End

        # Process day range
        $dayList = @()
        if ($daysRange -match "^(.+)-(.+)$") {
            $startDay = $matches[1].Trim()
            $endDay = $matches[2].Trim()
            
            if (-not $dayMap.ContainsKey($startDay) -or -not $dayMap.ContainsKey($endDay)) {
                Write-Host "❌ Invalid day format: '$daysRange'" -ForegroundColor Red
                continue
            }
            
            $dayStart = $dayMap[$startDay]
            $dayEnd = $dayMap[$endDay]
            
            # Handle day cycle (e.g., F-M spans the weekend)
            if ($dayStart -le $dayEnd) {
                for ($day = $dayStart; $day -le $dayEnd; $day++) {
                    $dayList += $day
                }
            } else {
                # Cycle: from start day to Saturday (6)
                for ($day = $dayStart; $day -le 6; $day++) {
                    $dayList += $day
                }
                # And from Sunday (0) to end day
                for ($day = 0; $day -le $dayEnd; $day++) {
                    $dayList += $day
                }
            }
        } else {
            # Single day
            if (-not $dayMap.ContainsKey($daysRange)) {
                Write-Host "❌ Invalid day: '$daysRange'" -ForegroundColor Red
                continue
            }
            $dayList = @($dayMap[$daysRange])
        }
        
        # Apply hour range to each day
        foreach ($day in $dayList) {
            # AD handles end time as exclusive (e.g., 9PM means up to but not including 9PM)
            $lastHour = $endHour - 1
            for ($hour = $startHour; $hour -le $lastHour; $hour++) {
                $bit = ($day * 24) + $hour
                $byteIndex = [math]::Floor($bit / 8)
                $bitIndex = $bit % 8
                $logonHours[$byteIndex] = $logonHours[$byteIndex] -bor (1 -shl $bitIndex)
            }
        }
    }

    # Apply settings to selected users
    foreach ($user in $users) {
        try {
            Set-ADUser -Identity $user.SamAccountName -Replace @{logonHours = $logonHours} -ErrorAction Stop
            Write-Host "✅ LogonHours applied to $($user.Name)" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed for $($user.Name): $_" -ForegroundColor Red
        }
    }
}

# --- MAIN INTERACTIVE FLOW ---
try {
    # Get all organizational units
    $ous = Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName
    Write-Host "`nAvailable Organizational Units:`n"
    for ($i = 0; $i -lt $ous.Count; $i++) {
        Write-Host "$i. $($ous[$i])"
    }
    $ouIndex = Read-Host "`nSelect OU number"
    
    if ($ouIndex -notmatch '^\d+$' -or [int]$ouIndex -ge $ous.Count) {
        Write-Host "❌ Invalid selection." -ForegroundColor Red
        exit
    }
    
    $selectedOU = $ous[$ouIndex]

    # Get users from selected OU
    $users = Get-ADUser -SearchBase $selectedOU -Filter * | Select-Object Name, SamAccountName
    if ($users.Count -eq 0) {
        Write-Host "⚠️ No users found in that OU." -ForegroundColor Yellow
        exit
    }

    # Display users for selection
    Write-Host "`nSelect user:"
    for ($i = 0; $i -lt $users.Count; $i++) {
        Write-Host "$i. $($users[$i].Name)"
    }
    Write-Host "$($users.Count). Apply to all users"

    $userSelection = Read-Host "Enter number"
    if ($userSelection -match '^\d+$') {
        if ([int]$userSelection -eq $users.Count) {
            # All users
            Write-Host "Selected all users in $selectedOU" -ForegroundColor Cyan
        } elseif ([int]$userSelection -lt $users.Count) {
            $users = @($users[[int]$userSelection])
            Write-Host "Selected: $($users[0].Name)" -ForegroundColor Cyan
        } else {
            Write-Host "❌ Invalid selection." -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "❌ Invalid input." -ForegroundColor Red
        exit
    }

    Show-DayLegend

    # Interactive menu for time range configuration
    $tramos = @()
    do {
        Write-Host "`nCurrent time ranges:"
        if ($tramos.Count -eq 0) {
            Write-Host "[none - users will not be able to log in]" -ForegroundColor Yellow
        } else {
            for ($i = 0; $i -lt $tramos.Count; $i++) {
                Write-Host "$i. $($tramos[$i].Days) from $($tramos[$i].Start):00 to $($tramos[$i].End):00"
            }
        }

        Write-Host "`nTime input examples:"
        Write-Host "  - Use whole hours only (minutes are ignored)"
        Write-Host "  - 24-hour format: '16' or '16:00'"
        Write-Host "  - AM/PM format: '4PM' or '9:00AM'"

        Write-Host "`nSelect an option:"
        Write-Host "1. Add a time range"
        Write-Host "2. Remove a time range"
        Write-Host "3. Save and apply"
        Write-Host "4. Cancel"
        $choice = Read-Host "Choice"

        switch ($choice) {
            "1" {
                Write-Host "`nExamples for days:"
                Write-Host "  - Weekdays: 'M-F'"
                Write-Host "  - Weekend: 'Sa-Su'"
                Write-Host "  - Single day: 'W'"
                $dayInput = Read-Host "Enter days (e.g., M-F or Sa)"
                
                Write-Host "`nExamples for times:"
                Write-Host "  - Business hours: '9AM' to '5PM'"
                Write-Host "  - Evening hours: '16' to '22'"
                $startInput = Read-Host "Enter start time (e.g., 16:00 or 4PM)"
                $endInput = Read-Host "Enter end time (e.g., 21:00 or 9PM)"
                
                try {
                    $startHour = ConvertToHour $startInput
                    $endHour = ConvertToHour $endInput
                    
                    if ($startHour -ge $endHour) {
                        Write-Host "❌ Start hour must be before end hour." -ForegroundColor Red
                    } else {
                        $tramos += [PSCustomObject]@{
                            Days  = $dayInput
                            Start = $startHour
                            End   = $endHour
                        }
                        Write-Host ("✓ Added range: " + $dayInput + " from " + $startHour + ":00 to " + $endHour + ":00") -ForegroundColor Green
                    }
                } catch {
                    Write-Host $_.Exception.Message -ForegroundColor Red
                }
            }
            "2" {
                if ($tramos.Count -gt 0) {
                    $remove = Read-Host "Enter range number to remove"
                    if ($remove -match '^\d+$' -and [int]$remove -lt $tramos.Count) {
                        $removed = $tramos[[int]$remove]
                        $tramos = $tramos | Where-Object { $_ -ne $tramos[[int]$remove] }
                        Write-Host ("Removed range: " + $removed.Days + " from " + $removed.Start + ":00 to " + $removed.End + ":00") -ForegroundColor Yellow
                    } else {
                        Write-Host "❌ Invalid range number." -ForegroundColor Red
                    }
                } else {
                    Write-Host "No ranges to remove." -ForegroundColor Yellow
                }
            }
            "3" {
                if ($tramos.Count -eq 0) {
                    $confirm = Read-Host "WARNING: No time ranges defined. Users will NOT be able to log in. Continue? (y/n)"
                    if ($confirm -ne "y") {
                        continue
                    }
                }
                # Show what's about to be applied
                Write-Host "`nApplying these logon hours:"
                foreach ($tramo in $tramos) {
                    Write-Host ("- " + $tramo.Days + " from " + $tramo.Start + ":00 to " + $tramo.End + ":00")
                }
                
                $confirm = Read-Host "Confirm application of these settings? (y/n)"
                if ($confirm -eq "y") {
                    Apply-LogonHours $users $tramos
                } else {
                    Write-Host "Application cancelled." -ForegroundColor Yellow
                }
                break
            }
            "4" {
                Write-Host "❌ Operation cancelled." -ForegroundColor Yellow
                break
            }
            default {
                Write-Host "❌ Invalid option. Choose 1-4." -ForegroundColor Red
            }
        }
    } while ($true)
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}
