function Get-CMAppApprovalHistory($requestObject){
    ($requestObject | Get-CimInstance).RequestHistory | ForEach-Object {
    
        [PSCustomObject]@{
            Comments = $_.Comments
            Date = $_.ModifiedDate
            State = $_.State
        }
    } | Sort-Object -Property Date
}

function Get-scupPSCharacterCount($string,$char){
    ($string.ToCharArray() | Where-Object {$_ -eq $char} | Measure-Object).Count
}

function Get-scupPSGeneratedUsername($firstname,$surname,$list){
    
    $syntax = @()
    $syntax += "LLLLFF"
    $syntax += "LLLFFF"
    $syntax += "LLFFFF"
    $syntax += "LLLLLF"
    $syntax += "LLLLLL"

    $electedName = $null
    
    foreach($syn in $syntax){
        $L = Get-scupPSCharacterCount -string $syn -char "L"
        $F = Get-scupPSCharacterCount -string $syn -char "F"
        
        if(!$electedName){
            if(!($L -gt $surname.Length) -or ($F -gt $firstname.Length)){
                $Genname = $surname.Substring(0,$L) + $firstname.Substring(0,$F)
                if(!($list.GetEnumerator() | Where-Object { $_ -eq $Genname })){
                    $electedName = $Genname
                }
            }
        }
    }

    return $electedName.ToLower()
}

function Get-StringHash([String] $String,$HashName = "MD5") 
{ 
    $StringBuilder = New-Object System.Text.StringBuilder 
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))| Foreach-Object { 
    [Void]$StringBuilder.Append($_.ToString("x2")) 
    } 
    $StringBuilder.ToString() 
}

function Send-CustomMailMessage(){
    param(
        [string]$smtpServer,
        [string]$from,
        [string]$subject,
        [array]$to,
        [string]$body,
        [switch]$BodyAsHtml,
        [array]$attachments,
        [string]$ReplyTo,
        [array]$CC
    )
    
    $message = New-Object System.Net.Mail.MailMessage
    $to | ForEach-Object {
        $message.To.Add($_)
    }

    if($CC){
        $CC | ForEach-Object {
            $message.CC.Add($_)
        }
    }
    
    $message.From = $from
    $message.Subject = $subject
    $message.Body = $body

    if($BodyAsHtml){
        $message.IsBodyHTML = $true
    }

    if($ReplyTo){
        $message.ReplyTo = $ReplyTo
    }

    if($attachments){
        $attachments | Foreach-Object {
            if(Test-Path -Path $_){
                $message.Attachments.Add($_)
            }else{
                Write-Error("Couldn't find attachment $_, breaking")
                break;
            }
        }
    }

    $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
    $smtp.Send($message)
    
}

function Send-AdminNotification(){
    param(
        [string]$subject,
        [string]$body
    )

    Send-CustomMailMessage -SmtpServer (Get-scupPSValue -Name "smtpServer") -from (Get-scupPSValue -Name "smtpAdminRecipient") -subject $subject -to (Get-scupPSValue -Name "smtpAdminRecipient") -body $body -BodyAsHtml
}

function Get-HTMLString($Value){
    if(!$Value){
        $Value = ""
    }
    $Value = $Value.Replace("&","&amp;")
    $Value = $Value.Replace("`n","</br>")
    $Value = $Value.Replace("`t", "&emsp;")
    $Value = $Value.Replace("ä","&auml;")
    $Value = $Value.Replace("Ä","&Auml;")
    $Value = $Value.Replace("ö","&ouml;")
    $Value = $Value.Replace("Ö","&Ouml;")
    $Value = $Value.Replace("ü","&uuml;")
    $Value = $Value.Replace("Ü","&Uuml;")
    $Value = $Value.Replace("ß","&szlig;")
    $Value = $Value.Replace("€","&euro;")
    $Value = $Value.Replace("§","&sect;")
    return $Value
}

function Test-ADCredential {
    [CmdletBinding()]
    Param
    (
        [string]$UserName,
        [string]$Password
    )
    if (!($UserName) -or !($Password)) {
        Write-Warning 'Test-ADCredential: Please specify both user name and password'
    } else {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('domain')
        $DS.ValidateCredentials($UserName, $Password)
    }
}

function Get-UserBySid($sid){
    return ([adsisearcher]"(&(objectClass=person)(objectClass=user)(|(objectSid=$sid)(msExchMasterAccountSid=$sid)))").FindAll().properties
}