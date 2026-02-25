param($Request, $TriggerMetadata)

# Parse Input
$targetTags = $Request.Body.tags 
$action = $Request.Body.action ?? "stop"

try {
    Connect-AzAccount -Identity -ErrorAction Stop

    # Get all VMs first (to compare against our tag list)
    $allVMs = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"
    
    # Filter the list: Keep VM if it matches ANY tag in your JSON array
    $vmsToProcess = $allVMs | Where-Object {
        $match = $false
        foreach ($tagEntry in $targetTags) {
            # Check if the VM has this specific tag name AND the correct value
            if ($_.Tags[$tagEntry.Name] -eq $tagEntry.Value) {
                $match = $true
                break # Found a match, no need to check other tags for this VM
            }
        }
        $match
    }

    # Execution Logic
    if ($null -eq $vmsToProcess -or $vmsToProcess.Count -eq 0) {
        $msg = "No VMs matched the provided tags."
    } else {
        foreach ($vm in $vmsToProcess) {
            if ($action -eq "start") {
                Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -NoWait
            } else {
                Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -NoWait
            }
        }
        $msg = "Successfully triggered '$action' for $($vmsToProcess.Count) VMs."
    }

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 200
        Body = $msg
    })
}
catch {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 500
        Body = "Error: $($_.Exception.Message)"
    })
}