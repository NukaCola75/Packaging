$Kill_Process = @("chrome","firefox")



Function KILL_PROCESS($Process_ToKill)
{
        # Processus a tuer
        
        Foreach ($process in $Process_ToKill)
        {
                Try 
                {
                        Stop-Process -name $process -force -ErrorAction 'Stop'
                }
                Catch [Microsoft.PowerShell.Commands.ProcessCommandException]
                {
                    
                }
        }  
}

KILL_PROCESS $Kill_Process